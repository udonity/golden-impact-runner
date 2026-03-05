---
name: using-serena
description: Serena MCP を使ったセマンティックなコード操作・ナビゲーション・リファクタリングのパターンを提供する。「Serena を使って」「セマンティック検索」「シンボル解析」「シンボル操作」「参照を探す」「コードナビゲーション」「リネーム」など、Serena MCP の使い方が必要なときに使用する。
---

# Serena MCP の使い方

## 概要

Serena はシンボルベースのコード操作 MCP。ファイル全体ではなく関数・クラス単位で読み書きする。
ツールのパラメータ詳細が必要な場合 → [references/tool-catalog.md](references/tool-catalog.md)

**基本方針:** ファイル全体の読み込みより、シンボル操作を常に優先する。

## セッション初期化

```
1. activate_project project="project-name"
2. check_onboarding_performed
3. onboarding（未完了の場合のみ）
4. list_memories → 関連メモリを read_memory で読む
```

## ツール選択ガイド

| やりたいこと | ツール |
|---|---|
| ファイル構造を把握したい | `get_symbols_overview` を `depth=0` → 必要に応じて増やす |
| 特定のシンボルを検索 | `find_symbol` を `name_path_pattern` で |
| シンボルの実装を読みたい | `find_symbol` を `include_body=true` で |
| シンボルの参照を検索 | `find_referencing_symbols` |
| 正規表現でパターン検索 | `search_for_pattern` |
| ディレクトリ構造を確認 | `list_dir` |
| 名前でファイルを探す | `find_file` |
| シンボル本体を置き換え | `replace_symbol_body` |
| シンボルの前後に追加 | `insert_before_symbol` / `insert_after_symbol` |
| コードベース全体でリネーム | `rename_symbol` |
| メモリの確認・更新 | **updating-project-memories** スキルを参照 |

## コアパターン

### ファイル探索（高レベル → 詳細）

```
Step 1: get_symbols_overview relative_path="src/main.ts" depth=0
Step 2: get_symbols_overview relative_path="src/main.ts" depth=1
Step 3: find_symbol name_path_pattern="MyClass/myMethod" include_body=true
```

### 依存関係トレース

```
Step 1: find_symbol name_path_pattern="processData" relative_path="src/processor.ts"
Step 2: find_referencing_symbols name_path="processData" relative_path="src/processor.ts"
Step 3: 完全な依存ツリーのため、各呼び出し元に対して Step 1-2 を再帰的に繰り返す
```

### 安全なリファクタリング

```
Step 1: find_symbol name_path_pattern="MyClass/oldMethod" include_body=true
Step 2: find_referencing_symbols name_path="MyClass/oldMethod" relative_path="src/myclass.ts"
Step 3: think_about_task_adherence  ← 変更前に必ず呼ぶ
Step 4: replace_symbol_body name_path="MyClass/oldMethod" relative_path="src/myclass.ts" body="..."
Step 5: シグネチャ変更時は Step 2 の全呼び出し箇所を更新
```

### パターン検索

```
# コードファイルのみ
search_for_pattern substring_pattern="TODO:" restrict_search_to_code_files=true

# 設定ファイルを含む全ファイル
search_for_pattern substring_pattern="api-key" restrict_search_to_code_files=false

# コンテキスト付き
search_for_pattern substring_pattern="function.*async" context_lines_before=2 context_lines_after=3
```

## シンボルパス

`name_path_pattern` はスラッシュ区切りのパス:

```
find_symbol "MyClass/myMethod"        # クラス内の特定メソッド
find_symbol "get*" substring_matching=true  # 全 getter メソッド
```

## ルール

### 必須（省略不可）

| ID | ルール | 検証 |
|---|---|---|
| B001 | セッション開始時に `activate_project` + `check_onboarding_performed` | アクティベーションが出力に記録 |
| B002 | コード変更前に `think_about_task_adherence` を呼ぶ | 整合性確認が記録 |
| B003 | 非自明な検索シーケンスの後に `think_about_collected_information` を呼ぶ | 情報整理が記録 |
| B004 | 完了報告前に `think_about_whether_you_are_done` を呼ぶ | 完了確認が記録 |

- 精密なコード変更には Serena のシンボル編集ツールを使用する
- コードベース探索には Serena のナビゲーション（`list_dir` / `find_file` / `search_for_pattern`）を優先し、Glob/Grep は最後の手段

### 推奨

- スコープが分かっている場合は `relative_path` で検索を絞り込む
- 不確かなシンボル名には `substring_matching=true` を使う

## やってはいけないこと

| NG | 代替 |
|---|---|
| シンボル操作で十分なのにファイル全体を読む | `get_symbols_overview` / `find_symbol` |
| スコープが分かっているのに全体検索 | `relative_path` で絞り込む |
| ファイル間でシンボル参照を手動更新 | `rename_symbol` で自動更新 |
| `get_symbols_overview` で不必要に高い depth | `depth=0` から段階的に増やす |

## エラー対処

| 重大度 | 状況 | 対応 |
|---|---|---|
| 低 | 完全一致でシンボルが見つからない | `substring_matching=true` で再試行 |
| 中 | 期待するシンボルがファイルに存在しない | 問題を記録し、AskUserQuestion で確認 |
| 高 | リファクタリング対象の参照が予想以上に多い | 停止し、影響範囲をユーザーに提示 |

## 関連スキル

- **updating-project-memories** — Serena メモリの管理ワークフロー・品質基準
