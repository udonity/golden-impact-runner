---
name: writing-plans
description: 仕様や要件がある複数ステップのタスクに対して、コードに触れる前に使用する
---

# 計画の作成

## 概要

エンジニアがコードベースのコンテキストをまったく持たず、センスも怪しいことを前提に、包括的な実装計画を作成する。各タスクで触るべきファイル、コード、テスト、確認すべきドキュメント、テスト方法など、必要な情報をすべてドキュメント化する。計画全体を一口サイズのタスクとして提示する。DRY。YAGNI。TDD。頻繁なコミット。

熟練した開発者であるが、我々のツールセットや問題ドメインについてはほぼ何も知らないと仮定する。テスト設計についてもあまり詳しくないと仮定する。

**開始時にアナウンス:** 「writing-plansスキルを使って実装計画を作成します。」

**コンテキスト:** これはbrainstormingスキルが作成した専用ワークツリーで実行すべきである。

**計画の保存先:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

## 一口サイズのタスク粒度

**各ステップは1つのアクション（2-5分）:**
- 「失敗するテストを書く」 - ステップ
- 「実行して失敗することを確認する」 - ステップ
- 「テストを通すための最小限のコードを実装する」 - ステップ
- 「テストを実行して通ることを確認する」 - ステップ
- 「コミット」 - ステップ

## 計画ドキュメントのヘッダー

**すべての計画はこのヘッダーで始めなければならない:**

```markdown
# [機能名] 実装計画

> **Claudeへ:** 必須サブスキル: superpowers:executing-plansを使用して、この計画をタスクごとに実装すること。

**目標:** [何を構築するかを1文で説明]

**アーキテクチャ:** [アプローチについて2-3文]

**技術スタック:** [主要な技術/ライブラリ]

---
```

## タスク構造

````markdown
### タスク N: [コンポーネント名]

**ファイル:**
- 作成: `exact/path/to/file.ts`
- 変更: `exact/path/to/existing.ts:123-145`
- テスト: `tests/exact/path/to/test.ts`

**ステップ 1: 失敗するテストを書く**

```typescript
function testSpecificBehavior(): void {
    const result = someFunction(input);
    assert.strictEqual(result, expected);
}
```

**ステップ 2: テストを実行して失敗を確認する**

実行: `npx jest tests/path/test.ts --testNamePattern="test_name" --verbose`
期待値: FAIL 「function is not defined」

**ステップ 3: 最小限の実装を書く**

```typescript
function someFunction(input: string): string {
    return expected;
}
```

**ステップ 4: テストを実行して通過を確認する**

実行: `npx jest tests/path/test.ts --testNamePattern="test_name" --verbose`
期待値: PASS

**ステップ 5: コミット**

```bash
git add tests/path/test.ts src/path/file.ts
git commit -m "feat: add specific feature"
```
````

## 注意点
- 常に正確なファイルパスを指定する
- 計画内に完全なコードを記載する（「バリデーションを追加」ではなく）
- 期待される出力を含む正確なコマンドを記載する
- 関連するスキルを @ 構文で参照する
- DRY、YAGNI、TDD、頻繁なコミット

## 実行の引き継ぎ

計画を保存したら、実行方法の選択肢を提示する:

**「計画が完成し、`docs/plans/<filename>.md` に保存されました。実行方法は2つあります:**

**1. サブエージェント駆動（このセッション）** - タスクごとに新しいサブエージェントを起動し、タスク間でレビューを行い、素早くイテレーション

**2. 並列セッション（別セッション）** - 新しいセッションでexecuting-plansを開き、チェックポイント付きのバッチ実行

**どちらにしますか?」**

**サブエージェント駆動を選択した場合:**
- **必須サブスキル:** superpowers:subagent-driven-developmentを使用する
- このセッションに留まる
- タスクごとに新しいサブエージェント + コードレビュー

**並列セッションを選択した場合:**
- ワークツリーで新しいセッションを開くよう案内する
- **必須サブスキル:** 新しいセッションでsuperpowers:executing-plansを使用する
