# Golden Impact Runner — アーキテクチャ設計

## 概要

Flutter Golden Testの影響範囲を特定するCLIツール。
Git差分から変更ファイルを取得し、依存グラフを辿って影響を受けるGolden Testファイル一覧を出力する。

## 設計方針

- **最小限の外部パッケージ依存**（Phase 1）: dart:io + dart:convert + package:path
- **Phase 2以降**: `package:analyzer` で Widget 単位の解析に拡張
- Dart CLI ツールとして実装

## Phase 1 MVP: 処理フロー

```
git diff --name-only <base>...<head>
  ↓ .dart ファイルのみフィルタ
1. lib/ と test/ の全 .dart ファイルを走査
2. 各ファイルの import/export/part 文を正規表現で抽出
3. ファイル → ファイルの有向依存グラフを構築
4. 逆依存マップ (dependedOnBy) を構築
5. 変更ファイルを起点に逆依存を BFS で再帰探索
6. 到達ファイルのうち test/ 配下で matchesGoldenFile を含むものを抽出
  ↓
テストファイルパス一覧を出力（1行1パス）
```

## プロジェクト構造

```
golden_impact_runner/
├── bin/
│   └── golden_impact_runner.dart    # エントリポイント
├── lib/
│   ├── golden_impact_runner.dart    # barrel export
│   └── src/
│       ├── cli/
│       │   ├── args_parser.dart     # CLI引数パース
│       │   └── runner.dart          # メイン実行ロジック
│       ├── analyzer/
│       │   ├── import_parser.dart   # import/export/part 正規表現解析
│       │   ├── dependency_graph.dart # 有向グラフ + 逆依存マップ
│       │   └── golden_test_detector.dart # matchesGoldenFile 検出
│       └── git/
│           └── diff_provider.dart   # git diff ラッパー
├── test/
│   ├── analyzer/
│   │   ├── import_parser_test.dart
│   │   ├── dependency_graph_test.dart
│   │   └── golden_test_detector_test.dart
│   ├── cli/
│   │   ├── args_parser_test.dart
│   │   └── runner_test.dart
│   ├── git/
│   │   └── diff_provider_test.dart
│   └── integration/
│       └── end_to_end_test.dart
├── pubspec.yaml
├── analysis_options.yaml
└── CLAUDE.md
```

## コアコンポーネント設計

### 1. ImportParser
```dart
class ImportParser {
  /// Dart ファイルから import/export/part ディレクティブを抽出
  List<String> extractDependencies(String fileContent);

  /// 相対パスを絶対パスに解決
  String resolveImportPath(String importUri, String currentFilePath);
}
```

正規表現: `^\s*(?:import|export|part)\s+['"](.+?)['"]`

### 2. DependencyGraph
```dart
class DependencyGraph {
  /// ファイルパス → 依存先ファイルパスのセット
  final Map<String, Set<String>> dependsOn;

  /// ファイルパス → このファイルに依存しているファイルパスのセット
  final Map<String, Set<String>> dependedOnBy;

  /// プロジェクトルートから全 .dart ファイルを走査してグラフ構築
  factory DependencyGraph.build(String projectRoot);

  /// 変更ファイルから影響を受ける全ファイルを BFS で探索
  Set<String> findImpactedFiles(Set<String> changedFiles);
}
```

### 3. GoldenTestDetector
```dart
class GoldenTestDetector {
  /// ファイル内容に matchesGoldenFile が含まれるかチェック
  bool isGoldenTest(String fileContent);

  /// test/ 配下の Golden Test ファイル一覧を取得
  Set<String> findGoldenTests(String projectRoot);
}
```

### 4. DiffProvider
```dart
class DiffProvider {
  /// git diff で変更された .dart ファイル一覧を取得
  Future<Set<String>> getChangedFiles({
    String? baseBranch,
    String? headBranch,
  });
}
```

## CLI インターフェース

```bash
# 基本: main ブランチとの差分から影響 Golden Test を列挙
dart run golden_impact_runner

# ブランチ指定
dart run golden_impact_runner --base origin/main --head HEAD

# JSON出力
dart run golden_impact_runner --format json

# ドライラン（グラフ情報も出力）
dart run golden_impact_runner --verbose

# 特定ファイルを変更したと仮定して影響を見る（what-if）
dart run golden_impact_runner --changed lib/widgets/button.dart
```

## import 解決ルール

| import形式 | 解決方法 |
|-----------|---------|
| `'package:my_app/foo.dart'` | pubspec.yaml の name → lib/ からの相対パスに変換 |
| `'../models/user.dart'` | 現在ファイルからの相対パスを解決 |
| `'dart:core'` | 無視（SDK内部） |
| `'package:flutter/material.dart'` | 無視（外部パッケージ） |
| `'foo.g.dart'` | 生成ファイルとして追跡 |

## 出力フォーマット

### デフォルト（テキスト）
```
test/widgets/button_golden_test.dart
test/screens/home_screen_golden_test.dart
```

### JSON
```json
{
  "changed_files": ["lib/widgets/button.dart"],
  "impacted_files": ["lib/screens/home_screen.dart", "lib/widgets/button.dart"],
  "golden_tests": ["test/widgets/button_golden_test.dart", "test/screens/home_screen_golden_test.dart"]
}
```

## Phase 2: Widget 単位解析

`--analysis-mode=widget` で有効化。`lib/src/analyzer/widget/` に配置。

### 処理フロー

```
1. DependencyGraph を構築（Phase 1 と同じ）
2. 全 .dart ファイルの AST を1回パース
3. Widget 定義を収集（StatelessWidget/StatefulWidget を直接継承するクラス）
4. Widget 使用を検出（コンストラクタ呼び出しの名前マッチ）
5. BFS で影響伝搬:
   - Widget 定義を持つファイル → Widget 使用エッジのみで伝搬
   - Widget 定義を持たないファイル → ファイルレベル逆依存にフォールバック
6. Golden Test ファイルをフィルタして出力
```

### 既知の制約

- **同名 Widget の衝突**: 異なるファイルに同名の Widget が定義されている場合、後に走査された方で上書きされる。プロジェクト内で Widget 名を一意にすることを前提とする。
- **中間基底クラス**: `extends MyBaseWidget` のような間接継承は Widget として検出されない（`StatelessWidget`/`StatefulWidget` の直接継承のみ）。
- **名前ベースの使用検出**: 型解決なしの構文解析のため、Widget と同名の関数呼び出しが false positive になる可能性がある。
- **Widget定義ファイルのutilityコード**: Widget定義を含むファイルが定数や関数もexportしている場合、そのutility部分のみの変更でもWidgetエッジのみで伝搬される。結果として、importのみでWidgetを使わないファイルが影響範囲から漏れる可能性がある（false negative）。過検出削減とのトレードオフとして許容。

## Phase 3 以降の拡張ポイント

- モノレポ対応（pubspec.yaml の path 依存解決）
- インクリメンタルキャッシュ（.golden_impact_cache/）
- GitHub Actions 統合テンプレート
- アセット依存追跡
