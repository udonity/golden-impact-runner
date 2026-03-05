---
name: figma-conservative-recursive
description: FigmaフレームURLからPixel Perfectなコード実装を生成する。「Figmaを実装して」「デザインからコード生成」「Figmaフレームを実装」「FigmaデザインをFlutterに変換」「Figma URLからコンポーネント作成」などのリクエスト時にトリガーされる。
---

# Figma Conservative Recursive Implementation

FigmaフレームからPixel Perfectなコード実装を、サブエージェントによるConservative Recursive Approachで効率的に生成する。

**基本原則:** depth=1から段階的にデータ取得 + サブエージェントで全処理 = メインセッションのトークン消費を最小化（約500トークン）

## 使用するタイミング

**使用する場合:**
- FigmaフレームURLが提供され、コード実装が必要
- 「このFigmaフレームを実装して」「Figmaデザインからコードを生成」等のリクエスト

**使用しない場合:**
- デザインの確認・レビューのみ（実装不要）
- URLなしの一般的なUI実装リクエスト → URLを取得してから再度実行

## 必要な情報

| 項目 | 必須 | デフォルト |
|------|------|-----------|
| FigmaフレームURL（node-id含む） | はい | - |
| 技術スタック | いいえ | プロジェクトから自動検出 |
| 出力ディレクトリ | いいえ | プロジェクト規約に従う |

## プロセス

1. **URL解析（決定論的）**: `python scripts/parse-figma-url.py "<ユーザー入力>"` を実行し、`file_key`と`node_id`を取得。エラー時はユーザーに正しいURLを再入力してもらう
2. 技術スタックを自動検出（`pubspec.yaml` → Flutter、`package.json` → React等。ユーザー指定優先）
3. サブエージェントをディスパッチする → `references/figma-implementer-prompt.md` を読み込む（Step 1で取得した`file_key`と`node_id`を渡す）
   - Phase 1: depth=1で全体構造取得
   - Phase 2: ノードタイプ別に選択的詳細取得（エラー時はdepth-1でリトライ）
   - Phase 3: Phase 1+2のデータをマージ
   - Phase 4: マージデータから実装コード生成・ファイル作成
   - Phase 5: 要約を作成しメインに返却
4. **Phase 6（メインセッション）**: 要約を確認しユーザーに実装結果を報告
   - UIコンポーネントのみで完結 → 必要に応じて微調整して完了
   - 統合作業が必要（状態管理・API連携・ルーティング等） → **superpowers:writing-plans** で統合計画を作成し、実行方法を提示

**重要:** Phase 1-5はすべてサブエージェント内で実行。完全なFigmaデータや生成コード全体はメインセッションに返却しない。

## エラーハンドリング

| エラー | 対処 |
|--------|------|
| トークン制限 | depthを1減らしてリトライ → depth=1でも失敗時はノード分割 |
| ネットワークエラー | 3回まで自動リトライ（指数バックオフ: 1s, 2s, 4s） |
| 不正なURL | `scripts/parse-figma-url.py` がエラーを返す → ユーザーに正しいURLを再入力依頼 |
| アクセス権限(403) | ユーザーにFigmaアクセス権限の確認を依頼 |

## よくある間違い

**NG depth=4で一括取得:** トークン制限に達しやすい。常にdepth=1から段階的に取得する。

**NG メインセッションでFigma MCPを直接呼ぶ:** トークンが大量消費される。必ずサブエージェント内で処理する。

**NG 全ノードを同じdepthで取得:** ノードタイプに応じて最適なdepthを使い分ける。

**NG 生成コード全体をメインに返却:** 要約のみ返却し、ファイルはサブエージェントが直接作成する。

## コード品質基準

- Pixel Perfectな実装（±2px以内）
- プロジェクトのアーキテクチャ規約に従う
- コンポーネントは適切に分割（100行以下を目安）
- 再利用可能なパーツは共通コンポーネント化

## 統合

**必須:**
- Figma MCP サーバーが稼働していること（`.vscode/mcp.json`で設定）

**推奨ワークフロースキル:**
- **superpowers:writing-plans** - 複雑な画面の統合計画作成（状態管理・API連携・ルーティング等が必要な場合）
- **superpowers:verification-before-completion** - 実装完了後の検証
- **superpowers:requesting-code-review** - コードレビュー依頼
