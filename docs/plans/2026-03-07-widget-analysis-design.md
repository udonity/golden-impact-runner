# Phase 2: Widget単位の依存解析 — デザインドキュメント

## 概要

ファイル単位の粗い依存解析から、Widget単位の精密な解析に拡張する。
既存のファイルレベル解析（Phase 1）を維持したまま、新しいWidget解析パイプラインを
並行して追加するレイヤード拡張アプローチを採る。

## 動機

Phase 1のファイルレベル解析では、1ファイルに複数Widgetが定義されている場合、
関係のないWidgetの変更でもそのファイルに依存する全テストが影響対象になる。
Widget単位の解析により、実際に変更されたWidgetを使用しているテストのみに
影響範囲を絞り込み、CIの実行時間を短縮する。

## 成功基準

1. **過検出の削減が測定可能** — 同じ変更セットに対して `--analysis-mode=file` と
   `--analysis-mode=widget` で影響テスト数を比較できる
2. **CLIオプションで切り替え可能** — `--analysis-mode=widget` フラグで
   既存のファイルレベル解析と切り替え

## アーキテクチャ

### 全体構成

```
bin/golden_impact_runner.dart
  └── Runner
        ├── [--analysis-mode=file]   既存パイプライン（変更なし）
        │     ImportParser(正規表現) → DependencyGraph → GoldenTestDetector
        │
        └── [--analysis-mode=widget] 新規パイプライン
              WidgetAnalyzer(AST)
                ├── WidgetExtractor      — ファイルからWidget定義を抽出
                ├── WidgetUsageDetector  — Widget使用箇所を検出
                └── WidgetDependencyGraph — Widget単位の依存グラフ + BFS
              → GoldenTestDetector（既存を再利用）
```

### 設計方針

- **レイヤード拡張**: 既存コードに一切手を入れない。新規コードは `lib/src/analyzer/widget/` 配下
- **入出力はファイル単位**: git diff の入力もflutter testへの出力もファイルパス。中間の解析精度だけがWidget単位に上がる
- **GoldenTestDetector共有**: 最終的にテストファイルを返す役割は両モードで同じ

## 新規コンポーネント

### WidgetExtractor

ファイルのAST解析から、Widget定義（`StatelessWidget`/`StatefulWidget`のサブクラス）を抽出する。

```dart
// lib/src/analyzer/widget/widget_extractor.dart

class WidgetDefinition {
  final String name;        // 例: "MyButton"
  final String filePath;    // 例: "lib/widgets/my_button.dart"
  final String superclass;  // "StatelessWidget" or "StatefulWidget"
}

class WidgetExtractor {
  /// ファイルのASTを解析し、Widget定義を返す
  List<WidgetDefinition> extractWidgets(String filePath, String content);

  /// プロジェクト全体をスキャンし、全Widget定義を収集
  Map<String, List<WidgetDefinition>> extractAllWidgets(String projectRoot);
}
```

### WidgetUsageDetector

ASTの `InstanceCreationExpression` を訪問し、あるファイル内で使用されているWidgetを検出する。

```dart
// lib/src/analyzer/widget/widget_usage_detector.dart

class WidgetUsage {
  final String widgetName;   // 使用されているWidget名
  final String filePath;     // 使用しているファイル
}

class WidgetUsageDetector {
  /// ファイル内で使用されているWidgetを検出
  List<WidgetUsage> detectUsages(String filePath, String content);
}
```

### WidgetDependencyGraph

Widget単位のノードで依存グラフを構築し、BFS逆引きを行う。

```dart
// lib/src/analyzer/widget/widget_dependency_graph.dart

class WidgetDependencyGraph {
  /// Widget定義 → それを使用しているファイル/Widget の逆引きマップ
  final Map<String, Set<String>> dependedOnBy;

  factory WidgetDependencyGraph.build({
    required String projectRoot,
    required String packageName,
  });

  /// 変更ファイル → 影響を受けるファイル（テストファイル含む）を返す
  Set<String> findImpactedFiles(Set<String> changedFiles);
}
```

## CLIインターフェース

### 新規オプション

```
golden_impact_runner --analysis-mode=widget
```

- `--analysis-mode`: `file`（デフォルト）または `widget`
- 既存オプション（`--format`, `--verbose`, `--changed`, `--base`, `--head`, `--exclude`）は
  すべてそのまま両モードで動作

### Runner内の分岐

```dart
Future<void> run() async {
  final changedFiles = getChangedFiles();

  final Set<String> impactedFiles;
  if (analysisMode == 'widget') {
    final widgetGraph = WidgetDependencyGraph.build(
      projectRoot: projectRoot,
      packageName: packageName,
    );
    impactedFiles = widgetGraph.findImpactedFiles(changedFiles);
  } else {
    final graph = DependencyGraph.build(...);
    impactedFiles = graph.findImpactedFiles(changedFiles);
  }

  final goldenTests = detector.filterGoldenTests(impactedFiles);
  // 以降は共通（出力処理）
}
```

## 依存関係

```yaml
dependencies:
  path: ^1.8.0
  analyzer: ^7.0.0  # AST解析
```

## 型解決の戦略

### MVPスコープ: 名前ベースの簡易判定

```dart
bool isWidgetClass(ClassDeclaration node) {
  final superclass = node.extendsClause?.superclass.name2.lexeme;
  return superclass == 'StatelessWidget' ||
         superclass == 'StatefulWidget';
}
```

Widget使用検出も名前ベースで行う。`InstanceCreationExpression` のコンストラクタ名が
既知のWidget定義リストに含まれるかで判定する。

### MVPでのサポート外（将来の拡張）

以下はMVPでは対応しない。フル型解決（`AnalysisContext` による型階層の完全解決）で
将来対応する予定。

- **中間基底クラス経由のWidget判定**: `class Foo extends MyBaseWidget`（`MyBaseWidget extends StatelessWidget`）は、`Foo` をWidgetとして認識できない。ファイルレベルの依存追跡にフォールバックする
- **型アノテーションのみの依存**: `MyWidget? widget;` のような型参照は使用として検出しない
- **staticメソッド呼び出し**: `MyWidget.of(context)` のようなInheritedWidgetパターンは検出しない
- **関数経由の間接生成**: `buildWidget()` が `MyWidget()` を返す場合、呼び出し側では `MyWidget` への依存が検出されない。ファイルレベルの依存追跡にフォールバックする
- **ジェネリクス経由の間接依存**: ファイルレベルの依存追跡にフォールバックする

**フォールバック方針**: Widget単位で解決できないケースは、ファイルレベルの依存追跡と同等の結果になる。精度低下は起きない（改善もない）。

## テスト戦略

### WidgetExtractor 単体テスト

```
test/analyzer/widget/widget_extractor_test.dart
```

**サポート対象:**
- StatelessWidget を直接継承したクラス → 検出
- StatefulWidget を直接継承したクラス → 検出
- 1ファイルに複数Widget定義 → すべて検出
- ジェネリックWidget (`class MyWidget<T> extends StatelessWidget`) → 検出
- State<T> クラス → Widget定義として検出しない
- 通常のクラス（Widget以外を継承）→ 検出しない
- mixin, extension → 検出しない
- コメント内のクラス定義 → 検出しない

**サポート外（フォールバック動作を検証）:**
- abstract class BaseWidget extends StatelessWidget → 検出する（定義自体はWidget）。ただし使用検出でインスタンス化されないため、影響グラフに辺は生まれない
- 中間基底クラス経由 (`class Foo extends BaseWidget`) → Widget として検出しない。ファイルレベルの依存追跡にフォールバック。将来フル型解決で対応予定

### WidgetUsageDetector 単体テスト

```
test/analyzer/widget/widget_usage_detector_test.dart
```

**サポート対象:**
- コンストラクタ呼び出し: `MyWidget()`
- const コンストラクタ: `const MyWidget()`
- named コンストラクタ: `MyWidget.custom()`
- build() メソッド内でのネスト使用
- 変数への代入: `final w = MyWidget();`
- コレクション内の生成: `[MyWidget(), OtherWidget()]`
- 条件式内: `condition ? MyWidget() : OtherWidget()` → 両方検出
- 既知Widget名リストに含まれないクラスの生成 → 検出しない
- コメント内の記述 → 検出しない

**サポート外（フォールバック動作を検証）:**
- 型アノテーションのみ (`MyWidget? widget;`) → 使用として検出しない。将来型参照による暗黙的依存の追跡を検討
- staticメソッド呼び出し (`MyWidget.of(context)`) → 使用として検出しない。将来InheritedWidgetパターンの追跡を検討
- 関数経由の間接生成 → ファイルレベルの依存追跡にフォールバック。将来関数の戻り型解析で対応

### WidgetDependencyGraph 単体テスト

```
test/analyzer/widget/widget_dependency_graph_test.dart
```

**サポート対象:**
- Widget A が Widget B を使用 → B変更時にAが影響
- 推移的依存: A→B→C、C変更時にA,Bが影響
- Widget未使用ファイル(utils.dart)の変更 → importチェーンで追跡
- 1ファイルに Widget X, Y 定義。Xだけ使用 → X変更: 使用側が影響。Y変更: 使用側は影響しない
- Widgetを含まないファイルの変更 → ファイルレベルのimportチェーンにフォールバック

**サポート外（フォールバック動作を検証）:**
- 中間基底クラス経由の依存 → ファイルレベルの依存追跡にフォールバック。両モードで同じ結果
- パッケージ外のWidget使用（package:flutter/material.dart の Scaffold など）→ 外部パッケージは無視（Phase 1と同じ方針）
- ジェネリクス経由の間接依存 → ファイルレベルの依存追跡にフォールバック

### フィクスチャ

```
test/fixtures_widget/
  lib/
    widgets/
      button.dart            # StatelessWidget: AppButton
      card.dart              # StatelessWidget: AppCard（AppButtonを使用）
      dialog.dart            # StatefulWidget: AppDialog（AppCardを使用）
      utils.dart             # Widget以外のユーティリティクラス
      multi_widget.dart      # 1ファイルに WidgetA, WidgetB
      base_widget.dart       # abstract class BaseWidget extends StatelessWidget
      derived_widget.dart    # class DerivedWidget extends BaseWidget（サポート外ケース）
      indirect_usage.dart    # 関数経由でWidgetを返すヘルパー（サポート外ケース）
    models/
      user.dart              # Widgetではないファイル
  test/
    button_golden_test.dart
    card_golden_test.dart
    dialog_golden_test.dart
    multi_widget_golden_test.dart  # WidgetA のみの Golden Test
    derived_golden_test.dart       # DerivedWidget の Golden Test
```

### E2Eテスト

```
test/integration/widget_analysis_e2e_test.dart
```

**不変条件テスト:**
- `widget結果 ⊆ file結果`（Widget単位は常に同じか少ない影響範囲）

**精度改善の検証:**
- `multi_widget.dart` の WidgetB のみ変更した場合:
  - file モード → `multi_widget_golden_test.dart` が影響
  - widget モード → 影響なし（WidgetB の Golden Test がないため）

**サポート外のフォールバック検証:**
- `derived_widget.dart` 変更した場合:
  - file モード → `derived_golden_test.dart` が影響
  - widget モード → `derived_golden_test.dart` が影響（DerivedWidget はWidget と認識されないためファイルレベルにフォールバック）
  - 両モードで同じ結果になることを検証（精度低下がないことの保証）

## ファイル構成（新規追加分）

```
lib/src/analyzer/widget/
  widget_extractor.dart
  widget_usage_detector.dart
  widget_dependency_graph.dart

test/analyzer/widget/
  widget_extractor_test.dart
  widget_usage_detector_test.dart
  widget_dependency_graph_test.dart

test/integration/
  widget_analysis_e2e_test.dart

test/fixtures_widget/
  lib/widgets/   ... (フィクスチャファイル群)
  lib/models/    ... (フィクスチャファイル群)
  test/          ... (フィクスチャテストファイル群)
```
