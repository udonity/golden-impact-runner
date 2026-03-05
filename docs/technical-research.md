# Flutter Golden Test インパクト分析ツール：既存部品の技術調査

## 概要

「Git差分から変更されたWidgetを特定し、依存グラフを上流にたどって、影響を受けるGolden Testファイルの一覧を出力する」ツールを開発するにあたり、既存のOSSやパッケージがどこまで活用でき、どこからスクラッチで開発する必要があるかを調査した。結論として、**ファイルレベルの依存グラフ構築とGit差分取得はほぼ既存部品で賄えるが、Widget単位の依存解析とテストファイルへのマッピングはスクラッチ開発が必要**になる。

## 処理パイプラインの全体像

ツールは以下の4ステップで構成される。各ステップごとに既存部品の有無を整理する。

| ステップ | 処理内容 | 既存部品の有無 |
|----------|----------|--------------|
| 1. Git差分取得 | 変更ファイル一覧を取得 | ✅ ほぼそのまま使える |
| 2. 依存グラフ構築 | Widget/ファイル間の依存関係を解析 | 🔶 ファイルレベルはあり、Widget単位は要自作 |
| 3. 影響範囲の計算 | 変更ファイルから上流をたどる | 🔧 グラフ探索ロジックは自作 |
| 4. テストファイル特定 | 影響Widgetに対応するGoldenテストを列挙 | 🔧 マッピングロジックは自作 |

## ステップ1：Git差分取得（既存部品で十分）

### git コマンド（標準）

`git diff --name-only origin/main...HEAD` でPR内の変更ファイル一覧を取得できる。Dart/Flutter固有の処理は不要で、シェルコマンドで完結する。

### lint_staged（pub.dev パッケージ）

`lint_staged` パッケージは、git stagedファイルやdiff間の変更ファイルを取得するユーティリティを提供している。`--diff="branch1...branch2"` オプションで任意のリビジョン間の差分取得にも対応しており、pre-commitフック用途に設計されているが、差分ファイル列挙部分は流用可能。

### 評価

Git差分取得は完全に既存ツールで対応できるため、**スクラッチ開発は不要**。シェルの `git diff` をそのまま使うのが最もシンプル。

## ステップ2：依存グラフ構築（最も選択肢が分かれるポイント）

依存グラフの粒度（ファイルレベル vs Widget単位）によって、使える部品が大きく変わる。

### アプローチA：ファイルレベルの依存グラフ

#### Lakos（OSS, Dart 3対応, v2.0.6）

Dartファイル間の `import`/`export` 依存関係をGraphviz dot形式またはJSON形式で出力するCLIツール。

- ファイルをノード、import/exportをエッジとした有向グラフを生成
- JSON出力には `nodes`（各ファイルのメトリクス付き）と `edges`（from/to/directive）が含まれる
- 循環依存の検出、orphanノードの特定、各種メトリクス（inDegree/outDegree/instabilityなど）の計算が可能
- `lakos -f json -i test/** lib/` のようにlib配下のグラフをJSON出力し、プログラムから解析可能
- **制限**: ファイル単位であり、1ファイル内に複数Widgetがある場合は区別できない

```
lakos -f json lib/ | jq '.edges[] | select(.from | contains("common_button"))'
```

このように、変更ファイルが依存されているファイルをJSONから逆引きすることで、ファイルレベルの影響範囲を特定できる。

#### Flutter SDK内部の `dependency_graph.dart`

Flutter SDK の `flutter_tools` パッケージ内に、Widget Preview機能用の依存グラフ実装が存在する。

- `package:analyzer` を使い、各ファイルの `libraryImports2` からimportされているライブラリを解決
- `dependsOn`（このファイルがimportしているファイル）と `dependedOnBy`（このファイルをimportしているファイル）の双方向グラフを構築
- **そのまま使うことは困難**（flutter_toolsの内部実装であり、公開APIではない）だが、**実装パターンの参考として非常に有用**

具体的には以下のコードパターンが参考になる：

```dart
for (final LibraryImport importedLib in fragment.libraryImports2) {
  if (importedLib.importedLibrary2 == null) continue;
  final LibraryElement2 importedLibrary = importedLib.importedLibrary2!;
  // グラフにノードを追加し、双方向の依存関係を構築
}
```

### アプローチB：Widget単位の依存グラフ

#### DCM `analyze-widgets`（有料、OSS無料ライセンスあり）

DCM（Dart Code Metrics）の `analyze-widgets` コマンドは、Widget単位の依存関係を解析し、JSON出力で `usedBy`（このWidgetを使っているWidget一覧）と `usedWidgets`（このWidgetが使っているWidget一覧、パス・参照回数・型情報付き）を提供する。

JSON出力のフォーマット：

```json
{
  "name": "MyWidget",
  "usedBy": ["SomeWidget", "AnotherWidget"],
  "usedWidgets": [
    { "path": "/path/to/used/widget.dart", "references": 5, "type": "local" }
  ]
}
```

- Widget品質スコア、メソッドメトリクス、Bloc/Provider連携情報なども付加される
- **コスト**: CIでの利用には有料ライセンスが必要。ただし、OSSプロジェクトには無料ライセンスの申請制度がある
- **最大の利点**: Widget単位の `usedBy` がそのまま「共通Widget → 依存Widget」の逆引きに使える

#### `package:analyzer`（Dart SDK付属、無料）

Dart公式の静的解析ライブラリで、完全な型解決付きAST解析が可能。

- `AnalysisContextCollection` + `getResolvedUnit` でファイルの完全な型情報を取得
- `RecursiveAstVisitor` でAST内の `InstanceCreationExpression`（Widgetのコンストラクタ呼び出し）を探索可能
- 型情報が解決済みのため、「この `InstanceCreationExpression` が `StatelessWidget` のサブクラスか？」といった判定も可能

Widget依存グラフをスクラッチで組む場合の実装イメージ：

```dart
class WidgetUsageVisitor extends RecursiveAstVisitor<void> {
  final Set<String> usedWidgets = {};

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.staticType;
    if (type != null && isWidgetType(type)) {
      usedWidgets.add(node.constructorName.type.name2.lexeme);
    }
    super.visitInstanceCreationExpression(node);
  }
}
```

- **コスト**: 無料だが、Widget判定ロジック、グラフ構築、transitive解決をすべて自作する必要がある
- **注意**: `AnalysisContextCollection` の初期化はファイル数に応じて数秒〜十数秒かかる場合がある

#### `flutter_ast`（OSS）

DartファイルのAST → JSONシリアライズを行うパッケージ。buildメソッド内のWidget構造をJSON化できるが、**Dart SDK `>=2.17.0 <3.0.0` でDart 3未対応の可能性が高い**。現時点での採用は非推奨。

#### `flutter_analyzer_utils`

Flutter SDKのWidget型に対する `TypeChecker` 定数を大量に提供するパッケージ。`package:analyzer` と組み合わせて「このクラスはWidgetか？」の判定に使える補助ツール。

### アプローチ比較

| 項目 | Lakos（ファイルレベル） | DCM（Widget単位） | `package:analyzer`（自作） |
|------|----------------------|-------------------|--------------------------|
| 粒度 | ファイル単位 | Widget単位 | Widget単位（自作次第） |
| コスト | 無料 | 有料（OSS無料あり） | 無料 |
| 実装量 | JSON解析のみ | JSON解析のみ | AST走査＋グラフ構築を自作 |
| 精度 | 1ファイル1Widget前提なら十分 | 高い（Widget名レベル） | 実装次第で高精度 |
| Dart 3対応 | ✅ | ✅ | ✅ |
| CI統合 | 簡単 | ライセンス管理が必要 | 簡単 |

## ステップ3：影響範囲の計算（自作が必要）

変更されたファイル/Widgetを起点に、依存グラフを上流（`usedBy` / `dependedOnBy` 方向）にたどり、影響を受けるすべてのWidgetを列挙する処理。これは単純なグラフ探索（BFS/DFS）であり、既存ライブラリは不要だがスクラッチで書く必要がある。

Lakos のJSON出力を使う場合：

```
edges の to が変更ファイル → from が影響ファイル（再帰的にたどる）
```

DCM の JSON出力を使う場合：

```
変更Widget の usedBy → そのWidgetの usedBy → ... を再帰的にたどる
```

## ステップ4：テストファイルの特定（自作が必要）

影響Widget/ファイルの一覧から、対応するGolden Testファイルを特定する処理。これは既存ツールでは提供されておらず、**完全にスクラッチ開発が必要**。

### 実装方針の選択肢

- **命名規約ベース**: `lib/widgets/foo.dart` → `test/widgets/foo_golden_test.dart` のようにパス変換ルールを定義。最もシンプルで実用的
- **アノテーションベース**: テストファイル内に `// @golden-for: lib/widgets/foo.dart` のようなコメントを記述し、スクリプトでgrepする方式
- **設定ファイルベース**: YAML等でWidget → テストファイルのマッピングを明示的に定義する方式

## CLIツールの構成に使える部品

| パッケージ | 用途 | 備考 |
|-----------|------|------|
| `args`（pub.dev） | CLIの引数パース、コマンド定義 | Dart公式推奨 |
| `cli_util`（pub.dev） | SDK検出、ログ出力、プログレス表示 | Dart公式 |
| `path`（pub.dev） | ファイルパスの操作 | Dart標準 |
| `analyzer`（pub.dev） | AST解析、型解決 | 自作アプローチの中核 |
| `lakos`（pub.dev） | ファイル依存グラフのJSON出力 | ライブラリとしても使用可 |

## 推奨アーキテクチャ

個人開発の規模と段階的な開発を考慮すると、以下の3段階が現実的。

### Phase 1：ファイルレベル（最小MVP）

- **Git差分**: `git diff --name-only` をProcess.runで実行
- **依存グラフ**: Lakos の JSON出力をパースし、`edges` の逆引きマップを構築
- **影響範囲**: BFSで上流ファイルをたどる
- **テスト特定**: 命名規約（`lib/x.dart` → `test/x_golden_test.dart`）でマッチング
- **出力**: 改行区切りのファイルパス一覧

**スクラッチ開発量**: 約200〜400行程度（Dart CLIツール）

### Phase 2：Widget単位への拡張

- **依存グラフ**: `package:analyzer` でWidget単位の依存解析を追加（またはDCMのJSON出力を統合）
- **精度向上**: 1ファイル複数Widgetのケースに対応

**追加スクラッチ開発量**: 約300〜600行（AST Visitor + グラフ構築）

### Phase 3：CI統合・高度な機能

- **GitHub Actions統合**: ワークフロー定義テンプレート
- **キャッシュ**: 依存グラフの差分更新（毎回フルスキャンを避ける）
- **出力フォーマット**: JSON/改行区切り/flutter testコマンド直接実行の切り替え

## スクラッチ開発が必要な範囲のまとめ

| 機能 | 既存部品で対応 | スクラッチが必要 |
|------|--------------|----------------|
| Git差分取得 | ✅ git コマンド | — |
| ファイル依存グラフ | ✅ Lakos JSON | JSON解析コードのみ |
| Widget依存グラフ | 🔶 DCM有料 or — | `package:analyzer` でAST走査 |
| 上流たどり（BFS/DFS） | — | ✅ グラフ探索ロジック |
| テストファイル特定 | — | ✅ マッピングルール実装 |
| CLI骨格 | ✅ `args` + `cli_util` | コマンド定義のみ |
| 出力フォーマット | — | ✅ フォーマッタ（軽量） |

Phase 1（ファイルレベルMVP）であれば、**全体の約60%が既存部品で賄え、スクラッチ開発は200〜400行程度**に収まる見込み。Widget単位まで踏み込むPhase 2では、`package:analyzer` を使ったAST走査が追加で300〜600行必要になるが、Flutter SDK内部の `dependency_graph.dart` の実装パターンを参考にすれば設計の指針は明確に得られる。
