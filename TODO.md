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
- [x] DiffProvider 単体テスト（git操作のモック/実環境テスト）

### 未対応のimportパターン

- [x] conditional import（`import 'stub.dart' if (dart.library.io) 'real.dart'`）
- [x] deferred import（`import '...' deferred as ...`）
- [x] コメント内のimport文を無視する処理

### 実用性の改善

- [x] エラーハンドリング強化（存在しないプロジェクト、git未初期化など）
- [x] `dart pub global activate` によるグローバルインストール対応の確認
- [x] `--exclude` オプション（特定ディレクトリ/ファイルを除外）
- [x] 実プロジェクトでの動作検証（flutter/samples compass_app: 135ファイル・490エッジで正常動作確認）

---

## Phase 1.5: CI実用化

CI上で影響Golden Testに絞って `flutter test` を実行するために必要な機能。
[デザインドキュメント](docs/plans/2026-03-06-ci-readiness-design.md)

### 生成ファイル対応

- [ ] `.g.dart` / `.freezed.dart` / `.gr.dart` の変更を元ファイルへ正規化
- [ ] 元ファイルが存在しない場合のフォールバック

### `flutter test` コマンド出力

- [ ] `--format command` で `flutter test <files...>` を標準出力に出力
- [ ] 影響テスト0件の場合は空文字列を出力

### テスト

- [ ] 生成ファイル正規化の単体テスト
- [ ] `--format command` の出力テスト
- [ ] 実プロジェクトでのCI動作検証

---

## Phase 2: 精度向上

ファイル単位の粗い解析からWidget単位の精密な解析へ拡張する。
CI実用化後、オーバー検出が問題になった場合に着手。

### Widget単位の依存解析

- [ ] `package:analyzer` 導入（AST解析・型解決）
- [ ] WidgetUsageVisitor — `InstanceCreationExpression` からWidget使用を検出
- [ ] Widget型判定（`StatelessWidget`/`StatefulWidget` のサブクラスか）
- [ ] Widget単位の依存グラフ構築（1ファイル複数Widget対応）

### モノレポ対応

- [ ] `pubspec.yaml` の `path:` 依存を解析
- [ ] 複数パッケージ間の `package:` import を正しく解決
- [ ] Melos/very_good_cli ワークスペース構造への対応

### テスト特定の改善

- [ ] import解析 + `matchesGoldenFile` 検出の精度向上
- [ ] アノテーションベースのマッピング（`// @golden-for: lib/widgets/foo.dart`）

---

## Phase 3: パフォーマンス・拡張

大規模プロジェクトやチーム利用を想定した改善。

### パフォーマンス

- [ ] インクリメンタルキャッシュ（`.golden_impact_cache/`）
- [ ] 大規模プロジェクト（1000+ ファイル）での性能計測
- [ ] 並列ファイル読み込み（`Isolate` 活用）

### 出力・可視化

- [ ] Graphviz DOT形式の依存グラフ出力
- [ ] `--depth` オプション（BFS探索の深さ制限）

### アセット依存

- [ ] `Image.asset()` / `AssetImage()` のアセットパス検出
- [ ] `pubspec.yaml` の assets セクションとの照合

---

## 将来構想

- Theme/Style追跡（`Theme.of(context)` 経由の暗黙的依存）
- VS Code拡張（エディタ上でリアルタイムに影響範囲を表示）
- git履歴から暗黙的依存を学習（テスト失敗パターンとの相関分析）

---

## 参考資料

- [技術調査レポート](docs/technical-research.md)
- [アーキテクチャ設計](docs/architecture.md)
- [Phase 1.5 デザイン](docs/plans/2026-03-06-ci-readiness-design.md)
