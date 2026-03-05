---
name: using-git-worktrees
description: 現在のワークスペースから隔離された機能開発を始める際や、実装計画を実行する前に使用する
---

# Git Worktreeの使い方

## 概要

Git worktreeは同じリポジトリを共有する隔離されたワークスペースを作成し、ブランチを切り替えることなく複数のブランチで同時に作業できるようにする。

**基本原則:** 体系的なディレクトリ選択 + 安全性検証 = 信頼性の高い隔離。

**開始時にアナウンス:** 「using-git-worktreesスキルを使って隔離されたワークスペースをセットアップします。」

## ディレクトリ選択プロセス

以下の優先順位に従う:

### 1. 既存ディレクトリの確認

```bash
# 優先順位に従って確認
ls -d .worktrees 2>/dev/null     # 推奨（隠しディレクトリ）
ls -d worktrees 2>/dev/null      # 代替
```

**見つかった場合:** そのディレクトリを使用する。両方存在する場合、`.worktrees`が優先。

### 2. CLAUDE.mdの確認

```bash
grep -i "worktree.*director" CLAUDE.md 2>/dev/null
```

**指定がある場合:** 確認せずにそれを使用する。

### 3. ユーザーに確認

ディレクトリが存在せず、CLAUDE.mdにも指定がない場合:

```
worktreeディレクトリが見つかりません。どこにworktreeを作成しますか？

1. .worktrees/ （プロジェクトローカル、隠しディレクトリ）
2. ~/.config/superpowers/worktrees/<project-name>/ （グローバルな場所）

どちらがよいですか？
```

## 安全性検証

### プロジェクトローカルディレクトリの場合（.worktreesまたはworktrees）

**worktreeを作成する前に、ディレクトリがignoreされていることを必ず検証する:**

```bash
# ディレクトリがignoreされているか確認（ローカル、グローバル、システムのgitignoreを参照）
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

**ignoreされていない場合:**

Jesseのルール「壊れているものはすぐに直す」に従い:
1. .gitignoreに適切な行を追加する
2. 変更をコミットする
3. worktreeの作成に進む

**なぜ重要か:** worktreeの内容を誤ってリポジトリにコミットすることを防ぐ。

### グローバルディレクトリの場合（~/.config/superpowers/worktrees）

.gitignoreの検証は不要 - プロジェクトの外にあるため。

## 作成手順

### 1. プロジェクト名の検出

```bash
project=$(basename "$(git rev-parse --show-toplevel)")
```

### 2. Worktreeの作成

```bash
# フルパスを決定
case $LOCATION in
  .worktrees|worktrees)
    path="$LOCATION/$BRANCH_NAME"
    ;;
  ~/.config/superpowers/worktrees/*)
    path="~/.config/superpowers/worktrees/$project/$BRANCH_NAME"
    ;;
esac

# 新しいブランチでworktreeを作成
git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

### 3. プロジェクトセットアップの実行

自動検出して適切なセットアップを実行:

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

### 4. クリーンなベースラインの検証

worktreeがクリーンな状態で始まることを確認するためにテストを実行:

```bash
# 例 - プロジェクトに適したコマンドを使用
npm test
cargo test
pytest
go test ./...
```

**テストが失敗した場合:** 失敗を報告し、続行するか調査するか確認する。

**テストが通った場合:** 準備完了を報告する。

### 5. 場所の報告

```
Worktree準備完了: <フルパス>
テスト通過（<N>件のテスト、0件の失敗）
<機能名>の実装準備完了
```

## クイックリファレンス

| 状況 | アクション |
|-----------|--------|
| `.worktrees/`が存在する | それを使用する（ignoreを検証） |
| `worktrees/`が存在する | それを使用する（ignoreを検証） |
| 両方存在する | `.worktrees/`を使用する |
| どちらも存在しない | CLAUDE.mdを確認 → ユーザーに確認 |
| ディレクトリがignoreされていない | .gitignoreに追加 + コミット |
| ベースラインでテスト失敗 | 失敗を報告 + 確認 |
| package.json/Cargo.tomlがない | 依存関係のインストールをスキップ |

## よくある間違い

### ignore検証のスキップ

- **問題:** worktreeの内容がトラッキングされ、git statusを汚染する
- **修正:** プロジェクトローカルのworktreeを作成する前に必ず`git check-ignore`を使用する

### ディレクトリの場所を仮定する

- **問題:** 一貫性がなくなり、プロジェクトの慣習に違反する
- **修正:** 優先順位に従う: 既存 > CLAUDE.md > 確認

### テスト失敗のまま続行する

- **問題:** 新しいバグと既存の問題を区別できない
- **修正:** 失敗を報告し、続行の明示的な許可を得る

### セットアップコマンドのハードコーディング

- **問題:** 異なるツールを使用するプロジェクトで壊れる
- **修正:** プロジェクトファイル（package.jsonなど）から自動検出する

## ワークフロー例

```
あなた: using-git-worktreesスキルを使って隔離されたワークスペースをセットアップします。

[.worktrees/を確認 - 存在する]
[ignoreを検証 - git check-ignoreで.worktrees/がignoreされていることを確認]
[worktreeを作成: git worktree add .worktrees/auth -b feature/auth]
[npm installを実行]
[npm testを実行 - 47件通過]

Worktree準備完了: /Users/jesse/myproject/.worktrees/auth
テスト通過（47件のテスト、0件の失敗）
auth機能の実装準備完了
```

## レッドフラグ

**決してしてはならないこと:**
- ignoreされていることを確認せずにworktreeを作成する（プロジェクトローカル）
- ベースラインのテスト検証をスキップする
- 確認せずにテスト失敗のまま続行する
- 曖昧な場合にディレクトリの場所を仮定する
- CLAUDE.mdの確認をスキップする

**常にすべきこと:**
- ディレクトリの優先順位に従う: 既存 > CLAUDE.md > 確認
- プロジェクトローカルではディレクトリがignoreされていることを確認する
- プロジェクトセットアップを自動検出して実行する
- クリーンなテストベースラインを検証する

## 連携

**呼び出し元:**
- **brainstorming**（フェーズ4） - 設計が承認され実装が続く場合に必須
- **subagent-driven-development** - タスク実行前に必須
- **executing-plans** - タスク実行前に必須
- 隔離されたワークスペースが必要なすべてのスキル

**組み合わせ:**
- **finishing-a-development-branch** - 作業完了後のクリーンアップに必須
