---
name: requesting-code-review
description: タスク完了時、主要機能の実装後、またはマージ前に作業が要件を満たしているか検証する際に使用
---

# コードレビューの依頼

コードレビューサブエージェントをディスパッチして、問題が連鎖する前にキャッチする。

**基本原則:** 早期にレビュー、頻繁にレビュー。

## レビューを依頼するタイミング

**必須:**
- サブエージェント駆動開発での各タスク完了後
- 主要機能の完了後
- mainへのマージ前

**任意だが有益:**
- 行き詰まった時（新鮮な視点）
- リファクタリング前（ベースラインチェック）
- 複雑なバグ修正後

## 依頼方法

**1. git SHAを取得:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # または origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. code-reviewer サブエージェントをディスパッチ:**

Task ツールで `references/code-reviewer.md` のテンプレートを埋めてサブエージェントをディスパッチする

**プレースホルダー:**
- `{WHAT_WAS_IMPLEMENTED}` - 実装した内容
- `{PLAN_OR_REQUIREMENTS}` - 期待される動作
- `{BASE_SHA}` - 開始コミット
- `{HEAD_SHA}` - 終了コミット
- `{DESCRIPTION}` - 簡単な概要

**3. フィードバックへの対応:**
- Critical の問題は即座に修正
- Important の問題は次に進む前に修正
- Minor の問題は後で対応としてメモ
- レビュアーが間違っている場合は根拠を示して反論

## 例

```
[タスク2完了: 検証関数の追加]

あなた: 次に進む前にコードレビューを依頼しよう。

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[references/code-reviewer.md のテンプレートでサブエージェントをディスパッチ]
  WHAT_WAS_IMPLEMENTED: 会話インデックスの検証・修復関数
  PLAN_OR_REQUIREMENTS: docs/plans/deployment-plan.md のタスク2
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DESCRIPTION: verifyIndex() と repairIndex() を4種類の問題タイプで追加

[サブエージェントの返答]:
  強み: クリーンなアーキテクチャ、実際のテスト
  問題点:
    Important: 進捗インジケーターの欠如
    Minor: レポート間隔のマジックナンバー (100)
  評価: 次に進んでよい

あなた: [進捗インジケーターを修正]
[タスク3に進む]
```

## ワークフローとの統合

**サブエージェント駆動開発:**
- 各タスク後にレビュー
- 問題が蓄積する前にキャッチ
- 次のタスクに移る前に修正

**計画の実行:**
- バッチごと（3タスク）にレビュー
- フィードバックを受け取り、適用し、続行

**アドホック開発:**
- マージ前にレビュー
- 行き詰まった時にレビュー

## 注意すべき問題

**禁止事項:**
- 「シンプルだから」とレビューをスキップ
- Critical の問題を無視
- 未修正の Important の問題があるまま進行
- 妥当な技術的フィードバックに対する反論

**レビュアーが間違っている場合:**
- 技術的根拠を示して反論
- 動作を証明するコード/テストを提示
- 明確化を要求

テンプレートは次の場所を参照: references/code-reviewer.md
