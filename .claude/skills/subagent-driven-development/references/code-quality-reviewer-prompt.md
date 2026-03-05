# コード品質レビュアープロンプトテンプレート

コード品質レビューサブエージェントをディスパッチする際にこのテンプレートを使用します。

**目的:** 実装が適切に構築されているか検証する（クリーン、テスト済み、保守可能）

**仕様準拠レビューがパスした後にのみディスパッチすること。**

```
Task ツール:
  requesting-code-review/references/code-reviewer.md のテンプレートを使用

  WHAT_WAS_IMPLEMENTED: [実装者のレポートから]
  PLAN_OR_REQUIREMENTS: [計画ファイル] のタスク N
  BASE_SHA: [タスク前のコミット]
  HEAD_SHA: [現在のコミット]
  DESCRIPTION: [タスクの概要]
```

**コードレビュアーの返却内容:** 強み、問題点 (Critical/Important/Minor)、評価
