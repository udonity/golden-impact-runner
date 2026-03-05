# Golden Impact Runner — TODO

Git差分から影響を受けるFlutter Golden Testを特定するCLIツール。

## Phase 1: ファイルレベルMVP

コア機能。正規表現ベースのimport解析でファイル単位の依存グラフを構築し、
変更ファイルからBFSで逆引きして影響Golden Testを列挙する。

### コア機能

- [x] ImportParser — import/export/part ディレクティブの正規表現解析
- [x] DependencyGraph — 有向依存グラフ構築 + 逆依存マップ + BFS探索
- [x] GoldenTestDetector — `matchesGoldenFile` パターンでGolden Test判定
- [x] DiffProvider — `git diff` ラッパー（変更 .dart ファイル一覧取得）
- [x] CLI — text/json出力、`--verbose`、`--changed`（what-if）、`--base`/`--head`

### テスト

- [x] ImportParser 単体テスト（import/export/part/part of/引用符/show,hide,as）
- [x] DependencyGraph 単体テスト（順方向・逆方向・推移的依存・無関係ファイル除外）
- [x] GoldenTestDetector 単体テスト（検出・非検出・フィルタリング）
- [x] E2Eテスト（fixture Flutterプロジェクトを使った統合テスト）
- [ ] DiffProvider 単体テスト（git操作のモック/実環境テスト）

### 未対応のimportパターン

- [ ] conditional import（`import 'stub.dart' if (dart.library.io) 'real.dart'`）
- [ ] deferred import（`import '...' deferred as ...`）
- [ ] コメント内のimport文を無視する処理

### 実用性の改善

- [ ] エラーハンドリング強化（存在しないプロジェクト、git未初期化など）
- [ ] `dart pub global activate` によるグローバルインストール対応の確認
- [ ] `--exclude` オプション（特定ディレクトリ/ファイルを除外）
- [ ] 実プロジェクトでの動作検証

---

## Phase 2: 精度向上

ファイル単位の粗い解析からWidget単位の精密な解析へ拡張する。

### Widget単位の依存解析

- [ ] `package:analyzer` 導入（AST解析・型解決）
- [ ] WidgetUsageVisitor — `InstanceCreationExpression` からWidget使用を検出
- [ ] Widget型判定（`StatelessWidget`/`StatefulWidget` のサブクラスか）
- [ ] `flutter_analyzer_utils` の TypeChecker 活用を検討
- [ ] Widget単位の依存グラフ構築（1ファイル複数Widget対応）

### 生成ファイル対応

- [ ] `.g.dart`（json_serializable, built_value）
- [ ] `.freezed.dart`（freezed）
- [ ] `.gr.dart`（auto_route）
- [ ] その他の生成パターン（`*.gen.dart`など）の設定可能化

### モノレポ対応

- [ ] `pubspec.yaml` の `path:` 依存を解析
- [ ] 複数パッケージ間の `package:` import を正しく解決
- [ ] Melos/very_good_cli ワークスペース構造への対応

### テスト特定の改善

- [ ] import解析 + `matchesGoldenFile` 検出の精度向上
- [ ] アノテーションベースのマッピング（`// @golden-for: lib/widgets/foo.dart`）
- [ ] 設定ファイルベースのマッピング（YAML定義）

---

## Phase 3: CI/CD統合・DX向上

開発ワークフローへの組み込みとチーム利用を想定した機能。

### GitHub Actions統合

- [ ] GitHub Actions ワークフローテンプレート（`.github/workflows/golden_test.yml`）
- [ ] PR自動コメント Bot（影響テスト一覧をPRにコメント）
- [ ] `flutter test` コマンドの直接生成（`--name` フィルタ付き）

### パフォーマンス

- [ ] インクリメンタルキャッシュ（`.golden_impact_cache/`）
  - 前回のグラフをキャッシュし、変更ファイルのみ再解析
- [ ] 大規模プロジェクト（1000+ ファイル）での性能計測とベンチマーク
- [ ] 並列ファイル読み込み（`Isolate` 活用）

### 出力・可視化

- [ ] Graphviz DOT形式の依存グラフ出力
- [ ] HTMLヒートマップレポート（影響範囲の可視化）
- [ ] `--depth` オプション（BFS探索の深さ制限）
- [ ] 重要度ソート（デザインシステムの根幹Widgetほど高重要度）

### アセット依存

- [ ] `Image.asset()` / `AssetImage()` のアセットパス検出
- [ ] フォント・JSONアセットの変更追跡
- [ ] `pubspec.yaml` の assets セクションとの照合

---

## Phase 4: 高度な機能（将来構想）

### Theme/Style追跡

- [ ] `Theme.of(context)` 経由の暗黙的依存を追跡
- [ ] ThemeData / TextStyle のグローバル変更の影響範囲特定

### 対話的機能

- [ ] What-If Explorer（対話的に「このファイルを変更したら？」をシミュレーション）
- [ ] VS Code拡張（エディタ上でリアルタイムに影響範囲を表示）

### 学習・予測

- [ ] git履歴から暗黙的依存を学習（過去のテスト失敗パターンとの相関分析）

---

## 参考資料

- [技術調査レポート](docs/technical-research.md)
- [アーキテクチャ設計](docs/architecture.md)
