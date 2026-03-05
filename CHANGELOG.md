# Changelog

## 0.1.1 — Phase 1.5: CI実用化

### 生成ファイル対応

- **GeneratedFileNormalizer** — `.g.dart` / `.freezed.dart` / `.gr.dart` の変更を元ファイルへ正規化
  - 元ファイルが存在しない場合は生成ファイル自体をフォールバック

### CLI

- `--format command` — `flutter test <files...>` 形式で標準出力に出力（CI連携用）
  - 影響テスト0件の場合は何も出力しない

### テスト

- 生成ファイル正規化の単体テスト（`.g.dart` / `.freezed.dart` / `.gr.dart` の3パターン + フォールバック）
- `--format command` の出力テスト
- E2Eテスト（生成ファイル変更 → 元ファイル正規化 → Golden Test検出のフルパイプライン）

## 0.1.0 — Phase 1: ファイルレベルMVP

### コア機能

- **ImportParser** — `import`/`export`/`part`/`part of` ディレクティブの正規表現解析
  - conditional import (`if (dart.library.*)`)
  - deferred import (`deferred as`)
  - コメント内のimport文を無視
- **DependencyGraph** — 有向依存グラフ構築 + 逆依存マップ + BFS探索
- **GoldenTestDetector** — Golden Test判定
  - `matchesGoldenFile(` パターン（標準Flutter）
  - `goldenTest(`・`GoldenTestGroup(`・`GoldenTestScenario(` パターン（Alchemist）
- **DiffProvider** — `git diff` ラッパー（変更 `.dart` ファイル一覧取得）

### CLI

- `dart run golden_impact_runner` で影響Golden Test一覧を出力
- `--format text|json` — 出力形式の選択
- `--verbose` — 詳細出力（依存グラフ統計情報）
- `--changed` — git diffの代わりにファイルを直接指定（what-if分析）
- `--base` / `--head` — 比較対象のブランチ/コミット指定
- `--exclude` — globパターンでファイル/ディレクトリを除外

### エラーハンドリング

- 存在しないプロジェクトディレクトリの検出
- ファイルをディレクトリとして指定した場合のエラー
- `pubspec.yaml` 不在・name フィールド不在の検出

### テスト

- ユニットテスト（ImportParser, DependencyGraph, GoldenTestDetector, DiffProvider, ArgsParser, Runner）
- 統合テスト（fixtureプロジェクトを使ったE2Eテスト）
- 実プロジェクト検証（flutter/samples compass_app: 135ファイル・490エッジで動作確認）
