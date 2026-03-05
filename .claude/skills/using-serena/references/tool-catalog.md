# Serena ツールカタログ

Serena MCP が提供する全ツールのパラメータ詳細。

## 目次

1. [セッション管理](#セッション管理)
2. [シンボル操作（読み取り）](#シンボル操作読み取り)
3. [シンボル操作（書き込み）](#シンボル操作書き込み)
4. [検索・ナビゲーション](#検索ナビゲーション)
5. [メモリ管理](#メモリ管理)
6. [リフレクション](#リフレクション)

---

## セッション管理

### activate_project

プロジェクトをアクティベートし、メモリとシンボルへのアクセスを有効化する。

| パラメータ | 必須 | 説明 |
|---|---|---|
| `project` | ○ | アクティベートするプロジェクト名 |

### check_onboarding_performed

オンボーディングが完了済みか確認する。`activate_project` の直後に呼ぶ。

### onboarding

初期オンボーディングを実行する。`check_onboarding_performed` が false のときのみ。

---

## シンボル操作（読み取り）

### get_symbols_overview

ファイル内のシンボルの高レベルビューを取得する。

| パラメータ | 必須 | 説明 |
|---|---|---|
| `relative_path` | ○ | 対象ファイルのパス |
| `depth` | — | 子孫の深さ。0=トップレベルのみ（デフォルト推奨） |

### find_symbol

名前パスパターンでシンボルを検索する。

| パラメータ | 必須 | 説明 |
|---|---|---|
| `name_path_pattern` | ○ | シンボル名またはパス（例: `MyClass/myMethod`） |
| `relative_path` | — | 検索スコープを絞り込む |
| `include_body` | — | ソースコードを含める |
| `depth` | — | 子孫を含める |
| `substring_matching` | — | 部分名でマッチさせる |

### find_referencing_symbols

シンボルへのすべての参照を検索する。

| パラメータ | 必須 | 説明 |
|---|---|---|
| `name_path` | ○ | 参照を検索するシンボル |
| `relative_path` | ○ | シンボルが含まれるファイル |

---

## シンボル操作（書き込み）

### replace_symbol_body

シンボル定義全体を置き換える。

| パラメータ | 必須 | 説明 |
|---|---|---|
| `name_path` | ○ | 置き換えるシンボル |
| `relative_path` | ○ | シンボルが含まれるファイル |
| `body` | ○ | 新しいシンボルの本体 |

### insert_before_symbol / insert_after_symbol

シンボルの前後にコンテンツを挿入する。

| パラメータ | 必須 | 説明 |
|---|---|---|
| `name_path` | ○ | 挿入先のシンボル |
| `relative_path` | ○ | シンボルが含まれるファイル |
| `body` | ○ | 挿入するコンテンツ |

### rename_symbol

コードベース全体でシンボルをリネームする（参照も自動更新）。

| パラメータ | 必須 | 説明 |
|---|---|---|
| `name_path` | ○ | リネームするシンボル |
| `relative_path` | ○ | シンボルが含まれるファイル |
| `new_name` | ○ | 新しいシンボル名 |

---

## 検索・ナビゲーション

### search_for_pattern

コードベース全体で正規表現検索を行う。

| パラメータ | 必須 | 説明 |
|---|---|---|
| `substring_pattern` | ○ | 正規表現パターン |
| `relative_path` | — | 検索スコープを絞り込む |
| `context_lines_before` / `after` | — | マッチ前後の行数 |
| `restrict_search_to_code_files` | — | コードファイルのみ or 全ファイル |
| `paths_include_glob` | — | 含めるファイルの glob |
| `paths_exclude_glob` | — | 除外するファイルの glob |

### list_dir

ディレクトリの内容を一覧表示する。

| パラメータ | 必須 | 説明 |
|---|---|---|
| `relative_path` | — | ディレクトリパス |
| `recursive` | — | サブディレクトリを含める |

### find_file

名前パターンでファイルを検索する。

| パラメータ | 必須 | 説明 |
|---|---|---|
| `file_name_pattern` | ○ | ファイル名パターン |
| `relative_path` | — | 検索スコープを絞り込む |

---

## メモリ管理

メモリの管理ワークフローは **updating-project-memories** スキルを参照。

| ツール | 用途 |
|---|---|
| `list_memories` | 利用可能なメモリ一覧 |
| `read_memory` | メモリ内容の読み取り |
| `write_memory` | 新規メモリ作成 |
| `edit_memory` | 既存メモリの部分更新（regex/literal） |
| `delete_memory` | メモリ削除（要ユーザー許可） |

---

## リフレクション

| ツール | タイミング |
|---|---|
| `think_about_collected_information` | 検索シーケンスの後 |
| `think_about_task_adherence` | コード変更の前 |
| `think_about_whether_you_are_done` | 完了報告の前 |
