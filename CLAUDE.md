# Golden Impact Runner

Flutter Golden Testの影響範囲を特定するDart CLIツール。

## プロジェクト概要

- Git差分 → 依存グラフ逆引き → 影響Golden Testファイル一覧出力
- Phase 1: 最小限の外部パッケージ依存（dart:io + dart:convert + package:path）
- Phase 2: `package:analyzer` でWidget単位の解析に拡張

## コマンド

- `dart run golden_impact_runner` — 影響Golden Test一覧を出力
- `dart test` — テスト実行
- `dart analyze` — 静的解析

## アーキテクチャ

詳細: `docs/architecture.md`

```
bin/golden_impact_runner.dart  → エントリポイント
lib/src/cli/                   → CLI引数パース・実行
lib/src/analyzer/              → import解析・依存グラフ・Golden Test検出
lib/src/git/                   → git diff ラッパー
```

## コーディング規約

- Dart標準のlintルール（`package:lints/recommended.yaml`相当）
- テストは `test/` にソースと同じディレクトリ構造で配置
- 外部パッケージ依存は最小限に（Phase 1では package:path のみ）
