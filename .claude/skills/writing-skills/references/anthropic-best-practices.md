# スキル作成のベストプラクティス

> Claudeが発見して効果的に使用できるスキルの書き方を学ぶ。

良いスキルは簡潔で、よく構造化されており、実際の使用でテストされている。このガイドは、Claudeが発見して効果的に使用できるスキルを書くための実践的な判断基準を提供する。

スキルの仕組みに関する概念的な背景については、[スキル概要](/en/docs/agents-and-tools/agent-skills/overview)を参照。

## 基本原則

### 簡潔さが鍵

[コンテキストウィンドウ](https://platform.claude.com/docs/en/build-with-claude/context-windows)は公共財である。スキルは、Claudeが知るべきすべての情報とコンテキストウィンドウを共有する:

* システムプロンプト
* 会話履歴
* 他のスキルのメタデータ
* 実際のリクエスト

スキル内のすべてのトークンに即座のコストがあるわけではない。起動時には、すべてのスキルからメタデータ（nameとdescription）のみがプリロードされる。Claudeはスキルが関連する場合にのみSKILL.mdを読み、追加ファイルは必要な場合にのみ読む。ただし、SKILL.mdの簡潔さは依然として重要である: Claudeがそれをロードすると、すべてのトークンが会話履歴や他のコンテキストと競合する。

**デフォルトの前提**: Claudeはすでに非常に賢い

Claudeがまだ持っていないコンテキストのみを追加する。各情報を吟味する:

* 「Claudeは本当にこの説明が必要か?」
* 「Claudeはこれを知っていると仮定できるか?」
* 「この段落はそのトークンコストを正当化できるか?」

**良い例: 簡潔**（約50トークン）:

````markdown  theme={null}
## PDFテキスト抽出

pdfplumberを使ったテキスト抽出:

```typescript
import pdfplumber from 'pdfplumber';

const pdf = await pdfplumber.open("file.pdf");
const text = pdf.pages[0].extractText();
```
````

**悪い例: 冗長すぎる**（約150トークン）:

```markdown  theme={null}
## PDFテキスト抽出

PDF（Portable Document Format）ファイルは、テキスト、画像、その他のコンテンツを含む
一般的なファイル形式です。PDFからテキストを抽出するには、ライブラリを使用する
必要があります。PDF処理には多くのライブラリがありますが、
pdfplumberは使いやすく、ほとんどのケースをうまく処理するため推奨します。
まず、pipでインストールする必要があります。その後、以下のコードを使用できます...
```

簡潔なバージョンは、ClaudeがPDFとは何か、ライブラリの仕組みを知っていることを前提とする。

### 適切な自由度を設定する

タスクの脆さと変動性に合わせて具体性のレベルを調整する。

**高い自由度**（テキストベースの指示）:

使用する場合:

* 複数のアプローチが有効
* 判断がコンテキストに依存する
* ヒューリスティクスがアプローチを導く

例:

```markdown  theme={null}
## コードレビュープロセス

1. コードの構造と構成を分析する
2. 潜在的なバグやエッジケースを確認する
3. 可読性と保守性の改善を提案する
4. プロジェクトの規約への準拠を検証する
```

**中程度の自由度**（擬似コードまたはパラメータ付きスクリプト）:

使用する場合:

* 推奨パターンが存在する
* ある程度のバリエーションが許容される
* 設定が動作に影響する

例:

````markdown  theme={null}
## レポート生成

このテンプレートを使い、必要に応じてカスタマイズする:

```typescript
function generateReport(data: Data, format: string = "markdown", includeCharts: boolean = true): void {
    // データを処理
    // 指定形式で出力を生成
    // オプションで可視化を含める
}
```
````

**低い自由度**（特定のスクリプト、パラメータがほとんどない）:

使用する場合:

* 操作が脆弱でエラーが発生しやすい
* 一貫性が重要
* 特定の順序に従う必要がある

例:

````markdown  theme={null}
## データベースマイグレーション

正確にこのスクリプトを実行する:

```bash
python scripts/migrate.py --verify --backup
```

コマンドを変更したり、追加のフラグを付けたりしないこと。
````

**アナロジー**: Claudeを道を探索するロボットと考える:

* **両側に崖がある狭い橋**: 安全に前進する方法は1つだけ。具体的なガードレールと正確な指示を提供する（低い自由度）。例: 正確な順序で実行しなければならないデータベースマイグレーション。
* **危険のない開けた野原**: 多くの道が成功に通じる。大まかな方向を示してClaudeに最適な道を見つけさせる（高い自由度）。例: コンテキストによって最適なアプローチが決まるコードレビュー。

### 使用予定のすべてのモデルでテストする

スキルはモデルへの追加として機能するため、効果はベースモデルに依存する。使用予定のすべてのモデルでスキルをテストすること。

**モデル別のテスト考慮事項**:

* **Claude Haiku**（高速、経済的）: スキルは十分なガイダンスを提供しているか?
* **Claude Sonnet**（バランス型）: スキルは明確で効率的か?
* **Claude Opus**（強力な推論）: スキルは過剰な説明をしていないか?

Opusで完璧に動作するものも、Haikuではより詳細が必要な場合がある。複数のモデルでスキルを使用する予定なら、すべてで適切に機能する指示を目指すこと。

## スキルの構造

<Note>
  **YAMLフロントマター**: SKILL.mdのフロントマターは2つのフィールドをサポートする:

  * `name` - スキルの人間が読める名前（最大64文字）
  * `description` - スキルが何をするか、いつ使うかの1行説明（最大1024文字）

  完全なスキル構造の詳細については、[スキル概要](/en/docs/agents-and-tools/agent-skills/overview#skill-structure)を参照。
</Note>

### 命名規約

スキルの参照や議論を容易にするため、一貫した命名パターンを使用する。スキル名には**動名詞形**（動詞 + -ing）の使用を推奨する。これはスキルが提供するアクティビティや能力を明確に表す。

**良い命名例（動名詞形）**:

* "Processing PDFs"
* "Analyzing spreadsheets"
* "Managing databases"
* "Testing code"
* "Writing documentation"

**許容される代替案**:

* 名詞句: "PDF Processing", "Spreadsheet Analysis"
* アクション指向: "Process PDFs", "Analyze Spreadsheets"

**避けるべきもの**:

* 曖昧な名前: "Helper", "Utils", "Tools"
* 過度に汎用的: "Documents", "Data", "Files"
* スキルコレクション内の不統一なパターン

一貫した命名により:

* ドキュメントや会話でスキルを参照しやすくなる
* スキルの内容が一目でわかる
* 複数のスキルの整理と検索が容易になる
* プロフェッショナルで統一感のあるスキルライブラリを維持できる

### 効果的なdescriptionの書き方

`description`フィールドはスキルの発見を可能にし、スキルが何をするかといつ使うかの両方を含めるべきである。

<Warning>
  **常に三人称で書くこと**。descriptionはシステムプロンプトに注入されるため、視点の不一致は発見の問題を引き起こす可能性がある。

  * **良い:** "Processes Excel files and generates reports"
  * **避ける:** "I can help you process Excel files"
  * **避ける:** "You can use this to process Excel files"
</Warning>

**具体的にキーとなる用語を含める**。スキルが何をするかと、いつ使うかの具体的なトリガー/コンテキストの両方を含める。

各スキルにはdescriptionフィールドが1つだけある。descriptionはスキル選択にとって重要である: Claudeはこれを使って、潜在的に100以上の利用可能なスキルから適切なスキルを選ぶ。descriptionには、Claudeがこのスキルをいつ選択すべきかを判断するのに十分な詳細を含める必要があり、SKILL.mdの残りの部分が実装の詳細を提供する。

効果的な例:

**PDF処理スキル:**

```yaml  theme={null}
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

**Excel分析スキル:**

```yaml  theme={null}
description: Analyze Excel spreadsheets, create pivot tables, generate charts. Use when analyzing Excel files, spreadsheets, tabular data, or .xlsx files.
```

**Gitコミットヘルパースキル:**

```yaml  theme={null}
description: Generate descriptive commit messages by analyzing git diffs. Use when the user asks for help writing commit messages or reviewing staged changes.
```

曖昧なdescriptionは避ける:

```yaml  theme={null}
description: Helps with documents
```

```yaml  theme={null}
description: Processes data
```

```yaml  theme={null}
description: Does stuff with files
```

### 段階的開示パターン

SKILL.mdは概要として機能し、必要に応じてClaudeを詳細な資料に導く。オンボーディングガイドの目次のようなものである。段階的開示の仕組みについては、概要の[スキルの仕組み](/en/docs/agents-and-tools/agent-skills/overview#how-skills-work)を参照。

**実践的なガイダンス:**

* 最適なパフォーマンスのため、SKILL.mdの本文は500行以内に保つ
* この制限に近づいたらコンテンツを別ファイルに分割する
* 以下のパターンを使って指示、コード、リソースを効果的に整理する

#### 視覚的概要: シンプルから複雑へ

基本的なスキルはメタデータと指示を含むSKILL.mdファイルだけで始まる:

<img src="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=87782ff239b297d9a9e8e1b72ed72db9" alt="YAMLフロントマターとマークダウン本文を持つシンプルなSKILL.mdファイル" data-og-width="2048" width="2048" data-og-height="1153" height="1153" data-path="images/agent-skills-simple-file.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=280&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=c61cc33b6f5855809907f7fda94cd80e 280w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=560&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=90d2c0c1c76b36e8d485f49e0810dbfd 560w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=840&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=ad17d231ac7b0bea7e5b4d58fb4aeabb 840w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=1100&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=f5d0a7a3c668435bb0aee9a3a8f8c329 1100w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=1650&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=0e927c1af9de5799cfe557d12249f6e6 1650w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=2500&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=46bbb1a51dd4c8202a470ac8c80a893d 2500w" />

スキルが成長するにつれ、Claudeが必要な時にのみロードする追加コンテンツをバンドルできる:

<img src="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=a5e0aa41e3d53985a7e3e43668a33ea3" alt="reference.mdやforms.mdなどの追加リファレンスファイルのバンドル" data-og-width="2048" width="2048" data-og-height="1327" height="1327" data-path="images/agent-skills-bundling-content.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=280&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=f8a0e73783e99b4a643d79eac86b70a2 280w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=560&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=dc510a2a9d3f14359416b706f067904a 560w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=840&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=82cd6286c966303f7dd914c28170e385 840w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=1100&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=56f3be36c77e4fe4b523df209a6824c6 1100w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=1650&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=d22b5161b2075656417d56f41a74f3dd 1650w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=2500&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=3dd4bdd6850ffcc96c6c45fcb0acd6eb 2500w" />

完全なスキルディレクトリ構造は以下のようになる:

```
pdf/
├── SKILL.md              # メイン指示（トリガー時にロード）
├── FORMS.md              # フォーム入力ガイド（必要時にロード）
├── reference.md          # APIリファレンス（必要時にロード）
├── examples.md           # 使用例（必要時にロード）
└── scripts/
    ├── analyze_form.py   # ユーティリティスクリプト（実行され、ロードされない）
    ├── fill_form.py      # フォーム入力スクリプト
    └── validate.py       # バリデーションスクリプト
```

#### パターン1: リファレンス付きハイレベルガイド

````markdown  theme={null}
---
name: PDF Processing
description: Extracts text and tables from PDF files, fills forms, and merges documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
---

# PDF処理

## クイックスタート

pdfplumberでテキスト抽出:
```typescript
import pdfplumber from 'pdfplumber';

const pdf = await pdfplumber.open("file.pdf");
const text = pdf.pages[0].extractText();
```

## 高度な機能

**フォーム入力**: 完全なガイドは[FORMS.md](FORMS.md)を参照
**APIリファレンス**: すべてのメソッドは[REFERENCE.md](REFERENCE.md)を参照
**例**: 一般的なパターンは[EXAMPLES.md](EXAMPLES.md)を参照
````

Claudeは必要な時にのみFORMS.md、REFERENCE.md、またはEXAMPLES.mdをロードする。

#### パターン2: ドメイン固有の構成

複数のドメインを持つスキルの場合、無関係なコンテキストのロードを避けるためドメインごとにコンテンツを整理する。ユーザーが売上指標について質問するとき、Claudeは売上関連のスキーマだけを読めばよく、財務やマーケティングのデータは不要である。これによりトークン使用量が低く、コンテキストが焦点を絞ったものになる。

```
bigquery-skill/
├── SKILL.md (概要とナビゲーション)
└── reference/
    ├── finance.md (収益、請求指標)
    ├── sales.md (商談、パイプライン)
    ├── product.md (API使用状況、機能)
    └── marketing.md (キャンペーン、アトリビューション)
```

````markdown SKILL.md theme={null}
# BigQueryデータ分析

## 利用可能なデータセット

**財務**: 収益、ARR、請求 → [reference/finance.md](reference/finance.md)を参照
**営業**: 商談、パイプライン、アカウント → [reference/sales.md](reference/sales.md)を参照
**プロダクト**: API使用状況、機能、導入 → [reference/product.md](reference/product.md)を参照
**マーケティング**: キャンペーン、アトリビューション、メール → [reference/marketing.md](reference/marketing.md)を参照

## クイック検索

grepで特定の指標を検索:

```bash
grep -i "revenue" reference/finance.md
grep -i "pipeline" reference/sales.md
grep -i "api usage" reference/product.md
```
````

#### パターン3: 条件付き詳細

基本コンテンツを表示し、高度なコンテンツにリンクする:

```markdown  theme={null}
# DOCX処理

## ドキュメントの作成

新しいドキュメントにはdocx-jsを使用する。[DOCX-JS.md](DOCX-JS.md)を参照。

## ドキュメントの編集

簡単な編集には、XMLを直接変更する。

**変更履歴**: [REDLINING.md](REDLINING.md)を参照
**OOXMLの詳細**: [OOXML.md](OOXML.md)を参照
```

Claudeはユーザーがそれらの機能を必要とする場合にのみREDLINING.mdやOOXML.mdを読む。

### 深くネストされた参照を避ける

Claudeは、他の参照ファイルから参照されているファイルを部分的にしか読まない場合がある。ネストされた参照に遭遇すると、Claudeはファイル全体を読む代わりに`head -100`のようなコマンドでコンテンツをプレビューし、不完全な情報になることがある。

**SKILL.mdからの参照は1階層にとどめる**。すべてのリファレンスファイルはSKILL.mdから直接リンクし、必要時にClaudeが完全なファイルを読めるようにする。

**悪い例: 深すぎる**:

```markdown  theme={null}
# SKILL.md
See [advanced.md](advanced.md)...

# advanced.md
See [details.md](details.md)...

# details.md
Here's the actual information...
```

**良い例: 1階層**:

```markdown  theme={null}
# SKILL.md

**基本的な使い方**: [SKILL.md内の指示]
**高度な機能**: [advanced.md](advanced.md)を参照
**APIリファレンス**: [reference.md](reference.md)を参照
**例**: [examples.md](examples.md)を参照
```

### 長いリファレンスファイルには目次を付ける

100行を超えるリファレンスファイルには、先頭に目次を含める。これにより、Claudeが部分的な読み取りでプレビューする場合でも、利用可能な情報の全範囲を確認できる。

**例**:

```markdown  theme={null}
# APIリファレンス

## 目次
- 認証とセットアップ
- コアメソッド（作成、読み取り、更新、削除）
- 高度な機能（バッチ操作、Webhook）
- エラーハンドリングパターン
- コード例

## 認証とセットアップ
...

## コアメソッド
...
```

Claudeは必要に応じて完全なファイルを読むか、特定のセクションにジャンプできる。

ファイルシステムベースのアーキテクチャが段階的開示を可能にする仕組みの詳細については、以下の上級セクションの[ランタイム環境](#ランタイム環境)セクションを参照。

## ワークフローとフィードバックループ

### 複雑なタスクにはワークフローを使用する

複雑な操作を明確で順序立ったステップに分割する。特に複雑なワークフローの場合、Claudeがレスポンスにコピーして進捗をチェックできるチェックリストを提供する。

**例1: 調査合成ワークフロー**（コードなしのスキル向け）:

````markdown  theme={null}
## 調査合成ワークフロー

このチェックリストをコピーして進捗を追跡する:

```
調査進捗:
- [ ] ステップ1: すべてのソースドキュメントを読む
- [ ] ステップ2: 主要テーマを特定する
- [ ] ステップ3: 主張を相互参照する
- [ ] ステップ4: 構造化された要約を作成する
- [ ] ステップ5: 引用を検証する
```

**ステップ1: すべてのソースドキュメントを読む**

`sources/`ディレクトリ内の各ドキュメントをレビューする。主要な論点と裏付ける証拠をメモする。

**ステップ2: 主要テーマを特定する**

ソース間のパターンを探す。繰り返し現れるテーマは何か? ソース間で一致するまたは相違する点はどこか?

**ステップ3: 主張を相互参照する**

各主要な主張について、ソース資料に記載があることを確認する。各ポイントをどのソースが支持しているかをメモする。

**ステップ4: 構造化された要約を作成する**

発見をテーマごとに整理する。含めるもの:
- 主張
- ソースからの裏付ける証拠
- 対立する見解（ある場合）

**ステップ5: 引用を検証する**

すべての主張が正しいソースドキュメントを参照していることを確認する。引用が不完全な場合は、ステップ3に戻る。
````

この例はコードを必要としない分析タスクにワークフローがどのように適用されるかを示す。チェックリストパターンはあらゆる複雑な多段階プロセスに機能する。

**例2: PDFフォーム入力ワークフロー**（コード付きのスキル向け）:

````markdown  theme={null}
## PDFフォーム入力ワークフロー

完了した項目をチェックしながらこのチェックリストをコピーする:

```
タスク進捗:
- [ ] ステップ1: フォームを分析する（analyze_form.pyを実行）
- [ ] ステップ2: フィールドマッピングを作成する（fields.jsonを編集）
- [ ] ステップ3: マッピングを検証する（validate_fields.pyを実行）
- [ ] ステップ4: フォームに入力する（fill_form.pyを実行）
- [ ] ステップ5: 出力を検証する（verify_output.pyを実行）
```

**ステップ1: フォームを分析する**

実行: `python scripts/analyze_form.py input.pdf`

フォームフィールドとその位置を抽出し、`fields.json`に保存する。

**ステップ2: フィールドマッピングを作成する**

`fields.json`を編集して各フィールドに値を追加する。

**ステップ3: マッピングを検証する**

実行: `python scripts/validate_fields.py fields.json`

続行する前にバリデーションエラーを修正する。

**ステップ4: フォームに入力する**

実行: `python scripts/fill_form.py input.pdf fields.json output.pdf`

**ステップ5: 出力を検証する**

実行: `python scripts/verify_output.py output.pdf`

検証に失敗した場合は、ステップ2に戻る。
````

明確なステップにより、Claudeが重要なバリデーションをスキップすることを防ぐ。チェックリストは、Claudeとあなたの両方が多段階ワークフローの進捗を追跡するのに役立つ。

### フィードバックループを実装する

**一般的なパターン**: バリデーター実行 → エラー修正 → 繰り返し

このパターンは出力品質を大幅に向上させる。

**例1: スタイルガイド準拠**（コードなしのスキル向け）:

```markdown  theme={null}
## コンテンツレビュープロセス

1. STYLE_GUIDE.mdのガイドラインに従ってコンテンツを作成する
2. チェックリストに照らしてレビューする:
   - 用語の一貫性を確認する
   - 例が標準フォーマットに従っていることを確認する
   - 必須セクションがすべて含まれていることを確認する
3. 問題が見つかった場合:
   - 各問題を具体的なセクション参照とともにメモする
   - コンテンツを修正する
   - チェックリストを再度レビューする
4. すべての要件が満たされた場合にのみ続行する
5. ドキュメントを最終化して保存する
```

バリデーションループパターンをスクリプトの代わりにリファレンスドキュメントを使って示す。「バリデーター」はSTYLE_GUIDE.mdであり、Claudeが読んで比較することでチェックを行う。

**例2: ドキュメント編集プロセス**（コード付きのスキル向け）:

```markdown  theme={null}
## ドキュメント編集プロセス

1. `word/document.xml`を編集する
2. **即座にバリデーション**: `python ooxml/scripts/validate.py unpacked_dir/`
3. バリデーションに失敗した場合:
   - エラーメッセージを慎重にレビューする
   - XML内の問題を修正する
   - バリデーションを再実行する
4. **バリデーションが通った場合にのみ続行する**
5. リビルド: `python ooxml/scripts/pack.py unpacked_dir/ output.docx`
6. 出力ドキュメントをテストする
```

バリデーションループにより早期にエラーを捕捉できる。

## コンテンツガイドライン

### 時間に依存する情報を避ける

古くなる情報を含めない:

**悪い例: 時間に依存**（誤った情報になる）:

```markdown  theme={null}
2025年8月より前の場合は古いAPIを使用する。
2025年8月以降は新しいAPIを使用する。
```

**良い例**（「旧パターン」セクションを使う）:

```markdown  theme={null}
## 現在の方法

v2 APIエンドポイントを使用: `api.example.com/v2/messages`

## 旧パターン

<details>
<summary>レガシーv1 API（2025-08に廃止）</summary>

v1 APIは: `api.example.com/v1/messages` を使用していた。

このエンドポイントはサポートされなくなった。
</details>
```

旧パターンセクションにより、メインコンテンツを散らかすことなく歴史的なコンテキストを提供できる。

### 一貫した用語を使用する

1つの用語を選び、スキル全体で使用する:

**良い - 一貫性あり**:

* 常に「APIエンドポイント」
* 常に「フィールド」
* 常に「抽出」

**悪い - 不一致**:

* 「APIエンドポイント」「URL」「APIルート」「パス」を混在
* 「フィールド」「ボックス」「要素」「コントロール」を混在
* 「抽出」「引き出す」「取得」「取り込む」を混在

一貫性はClaudeが指示を理解し従うのに役立つ。

## 一般的なパターン

### テンプレートパターン

出力形式のテンプレートを提供する。ニーズに合わせて厳密さのレベルを調整する。

**厳格な要件向け**（APIレスポンスやデータ形式など）:

````markdown  theme={null}
## レポート構造

必ずこの正確なテンプレート構造を使用すること:

```markdown
# [分析タイトル]

## エグゼクティブサマリー
[主要な発見の1段落の概要]

## 主要な発見
- 裏付けデータ付きの発見1
- 裏付けデータ付きの発見2
- 裏付けデータ付きの発見3

## 推奨事項
1. 具体的で実行可能な推奨事項
2. 具体的で実行可能な推奨事項
```
````

**柔軟なガイダンス向け**（適応が有用な場合）:

````markdown  theme={null}
## レポート構造

妥当なデフォルト形式だが、分析に基づいて最善の判断を使うこと:

```markdown
# [分析タイトル]

## エグゼクティブサマリー
[概要]

## 主要な発見
[発見に基づいてセクションを適応]

## 推奨事項
[特定のコンテキストに合わせて調整]
```

特定の分析タイプに必要に応じてセクションを調整する。
````

### 例示パターン

出力品質が例を見ることに依存するスキルの場合、通常のプロンプティングと同様に入力/出力ペアを提供する:

````markdown  theme={null}
## コミットメッセージ形式

これらの例に従ってコミットメッセージを生成する:

**例1:**
入力: JWTトークンによるユーザー認証を追加
出力:
```
feat(auth): implement JWT-based authentication

Add login endpoint and token validation middleware
```

**例2:**
入力: レポートで日付が正しく表示されないバグを修正
出力:
```
fix(reports): correct date formatting in timezone conversion

Use UTC timestamps consistently across report generation
```

**例3:**
入力: 依存関係を更新し、エラーハンドリングをリファクタリング
出力:
```
chore: update dependencies and refactor error handling

- Upgrade lodash to 4.17.21
- Standardize error response format across endpoints
```

このスタイルに従う: type(scope): 簡潔な説明、次に詳細な説明。
````

例は、説明だけよりも、Claudeが望ましいスタイルと詳細レベルを理解するのに役立つ。

### 条件付きワークフローパターン

判断ポイントを通じてClaudeを導く:

```markdown  theme={null}
## ドキュメント変更ワークフロー

1. 変更タイプを決定する:

   **新しいコンテンツの作成?** → 以下の「作成ワークフロー」に従う
   **既存コンテンツの編集?** → 以下の「編集ワークフロー」に従う

2. 作成ワークフロー:
   - docx-jsライブラリを使用する
   - ドキュメントをゼロから構築する
   - .docx形式にエクスポートする

3. 編集ワークフロー:
   - 既存のドキュメントを展開する
   - XMLを直接変更する
   - 各変更後にバリデーションする
   - 完了したら再パックする
```

<Tip>
  ワークフローが多くのステップで大きく複雑になった場合は、別ファイルに移し、タスクに応じて適切なファイルを読むようClaudeに指示することを検討する。
</Tip>

## 評価とイテレーション

### 評価を先に構築する

**広範なドキュメントを書く前に評価を作成する。** これにより、スキルが想像上の問題ではなく実際の問題を解決することを保証する。

**評価駆動開発:**

1. **ギャップを特定する**: スキルなしでClaudeに代表的なタスクを実行させる。具体的な失敗や不足しているコンテキストをドキュメント化する
2. **評価を作成する**: これらのギャップをテストする3つのシナリオを構築する
3. **ベースラインを確立する**: スキルなしでClaudeのパフォーマンスを測定する
4. **最小限の指示を書く**: ギャップに対処し評価に通るために十分なコンテンツだけを作成する
5. **イテレーションする**: 評価を実行し、ベースラインと比較し、改善する

このアプローチにより、実現しないかもしれない要件を予想するのではなく、実際の問題を解決できる。

**評価の構造**:

```json  theme={null}
{
  "skills": ["pdf-processing"],
  "query": "このPDFファイルからすべてのテキストを抽出し、output.txtに保存してください",
  "files": ["test-files/document.pdf"],
  "expected_behavior": [
    "適切なPDF処理ライブラリまたはコマンドラインツールを使用してPDFファイルを正常に読み取る",
    "ページを見落とすことなくドキュメントのすべてのページからテキストコンテンツを抽出する",
    "抽出したテキストを明確で読みやすい形式でoutput.txtというファイルに保存する"
  ]
}
```

<Note>
  この例はシンプルなテストルーブリックを持つデータ駆動の評価を示す。現在、これらの評価を実行する組み込みの方法は提供していない。ユーザーは独自の評価システムを作成できる。評価はスキルの効果を測定するための唯一の真実の情報源である。
</Note>

### Claudeと反復的にスキルを開発する

最も効果的なスキル開発プロセスにはClaude自身が関与する。1つのClaudeインスタンス（「Claude A」）と協力して、他のインスタンス（「Claude B」）が使用するスキルを作成する。Claude Aは指示の設計と改善を助け、Claude Bは実際のタスクでそれらをテストする。これが機能するのは、Claudeモデルが効果的なエージェント指示の書き方と、エージェントが必要とする情報の両方を理解しているからである。

**新しいスキルの作成:**

1. **スキルなしでタスクを完了する**: 通常のプロンプティングでClaude Aと問題を解決する。作業中に、自然とコンテキストを提供し、好みを説明し、手続き的な知識を共有する。繰り返し提供する情報に注目する。

2. **再利用可能なパターンを特定する**: タスク完了後、類似の将来のタスクに有用なコンテキストを特定する。

   **例**: BigQuery分析を行った場合、テーブル名、フィールド定義、フィルタリングルール（「常にテストアカウントを除外」など）、一般的なクエリパターンを提供したかもしれない。

3. **Claude Aにスキルの作成を依頼する**: 「先ほど使ったBigQuery分析パターンをキャプチャするスキルを作成してください。テーブルスキーマ、命名規約、テストアカウントフィルタリングのルールを含めてください。」

   <Tip>
     Claudeモデルはスキルの形式と構造をネイティブに理解している。Claudeにスキルの作成を助けてもらうために特別なシステムプロンプトや「スキル作成」スキルは必要ない。単にスキルの作成を依頼すれば、適切なフロントマターと本文コンテンツを持つ正しい構造のSKILL.mdコンテンツを生成する。
   </Tip>

4. **簡潔さをレビューする**: Claude Aが不必要な説明を追加していないか確認する。「勝率の意味についての説明を削除してください - Claudeはすでにそれを知っています。」と依頼する。

5. **情報アーキテクチャを改善する**: Claude Aにコンテンツをより効果的に整理するよう依頼する。例: 「テーブルスキーマが別のリファレンスファイルにあるように整理してください。後でテーブルを追加するかもしれません。」

6. **類似のタスクでテストする**: スキルがロードされたClaude B（新しいインスタンス）で関連するユースケースをテストする。Claude Bが正しい情報を見つけ、ルールを正しく適用し、タスクを正常に処理するか観察する。

7. **観察に基づいてイテレーションする**: Claude Bが苦戦したり何かを見落としたりした場合、具体的な内容をClaude Aに報告する: 「ClaudeがこのスキルでQ4の日付フィルタリングを忘れました。日付フィルタリングパターンのセクションを追加すべきでしょうか?」

**既存スキルのイテレーション:**

スキル改善時も同じ階層的パターンが続く。以下を交互に行う:

* **Claude Aと作業**（スキルの改善を助けるエキスパート）
* **Claude Bでテスト**（スキルを使って実際の作業を行うエージェント）
* **Claude Bの動作を観察**し、洞察をClaude Aに持ち帰る

1. **実際のワークフローでスキルを使用する**: テストシナリオではなく、Claude B（スキルがロードされた状態）に実際のタスクを与える

2. **Claude Bの動作を観察する**: 苦戦する場所、成功する場所、予想外の選択をする場所をメモする

   **観察例**: 「Claude Bに地域別売上レポートを依頼したところ、クエリは書いたがテストアカウントのフィルタリングを忘れた。スキルにはこのルールが記載されているのだが。」

3. **改善のためにClaude Aに戻る**: 現在のSKILL.mdを共有し、観察内容を説明する。「地域レポートを依頼したときにClaude Bがテストアカウントのフィルタリングを忘れたことに気づきました。スキルにはフィルタリングが記載されていますが、十分に目立っていないのかもしれません。」と質問する。

4. **Claude Aの提案をレビューする**: Claude Aは、ルールをより目立たせるための再構成、「always filter」の代わりに「MUST filter」のようなより強い言語の使用、またはワークフローセクションの再構成を提案するかもしれない。

5. **変更を適用してテストする**: Claude Aの改善でスキルを更新し、同様のリクエストでClaude Bで再テストする

6. **使用状況に基づいて繰り返す**: 新しいシナリオに遭遇するたびに、この観察-改善-テストのサイクルを続ける。各イテレーションで、仮定ではなく実際のエージェントの動作に基づいてスキルが改善される。

**チームのフィードバックを収集する:**

1. チームメートとスキルを共有し、使用状況を観察する
2. 「スキルは期待通りにアクティベートされますか? 指示は明確ですか? 何が不足していますか?」と質問する
3. 自分の使用パターンの盲点に対処するためにフィードバックを取り入れる

**このアプローチが機能する理由**: Claude Aはエージェントのニーズを理解し、あなたがドメインの専門知識を提供し、Claude Bが実際の使用を通じてギャップを明らかにし、反復的な改善が仮定ではなく観察された動作に基づいてスキルを改善する。

### Claudeがスキルをどのようにナビゲートするかを観察する

スキルをイテレーションする際に、Claudeが実際にどのようにスキルを使用するかに注意を払う。以下を観察する:

* **予想外の探索パス**: Claudeが予想しなかった順序でファイルを読むか? これは構造が直感的でないことを示している可能性がある
* **見落とされた接続**: Claudeが重要なファイルへの参照をたどらないか? リンクがより明示的または目立つ必要があるかもしれない
* **特定セクションへの過度の依存**: Claudeが同じファイルを繰り返し読む場合、そのコンテンツをメインのSKILL.mdに移すことを検討する
* **無視されるコンテンツ**: Claudeがバンドルされたファイルにアクセスしない場合、それは不要であるか、メインの指示でうまく示されていない可能性がある

仮定ではなく、これらの観察に基づいてイテレーションする。スキルのメタデータの'name'と'description'は特に重要である。Claudeはこれらを使って、現在のタスクに対してスキルをトリガーするかどうかを決定する。スキルが何をするか、いつ使うべきかが明確に記述されていることを確認する。

## 避けるべきアンチパターン

### Windowsスタイルのパスを避ける

Windowsでも常にスラッシュを使用する:

* 良い: `scripts/helper.py`, `reference/guide.md`
* 避ける: `scripts\helper.py`, `reference\guide.md`

Unixスタイルのパスはすべてのプラットフォームで動作するが、Windowsスタイルのパスはunixシステムでエラーを引き起こす。

### 多すぎる選択肢の提示を避ける

必要でない限り複数のアプローチを提示しない:

````markdown  theme={null}
**悪い例: 選択肢が多すぎる**（混乱する）:
「pypdf、pdfplumber、PyMuPDF、pdf2imageなどを使用できます...」

**良い例: デフォルトを提供する**（エスケープハッチ付き）:
「テキスト抽出にはpdfplumberを使用する:
```typescript
import pdfplumber from 'pdfplumber';
```

OCRが必要なスキャンPDFの場合は、代わりにpdf2imageとpytesseractを使用する。」
````

## 上級: 実行可能コード付きスキル

以下のセクションは実行可能スクリプトを含むスキルに焦点を当てる。マークダウン指示のみのスキルの場合は、[効果的なスキルのチェックリスト](#効果的なスキルのチェックリスト)にスキップ。

### 解決する、丸投げしない

スキルのスクリプトを書く際は、Claudeに丸投げせずエラー条件を処理する。

**良い例: エラーを明示的に処理**:

```typescript  theme={null}
function processFile(path: string): string {
    /** ファイルを処理し、存在しない場合は作成する。 */
    try {
        return fs.readFileSync(path, 'utf-8');
    } catch (error) {
        if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
            // 失敗する代わりにデフォルトコンテンツでファイルを作成
            console.log(`ファイル ${path} が見つかりません。デフォルトを作成します`);
            fs.writeFileSync(path, '');
            return '';
        } else if ((error as NodeJS.ErrnoException).code === 'EACCES') {
            // 失敗する代わりに代替手段を提供
            console.log(`${path} にアクセスできません。デフォルトを使用します`);
            return '';
        }
        throw error;
    }
}
```

**悪い例: Claudeに丸投げ**:

```typescript  theme={null}
function processFile(path: string): string {
    // 単に失敗してClaudeに解決させる
    return fs.readFileSync(path, 'utf-8');
}
```

設定パラメータも、「呪いの定数」（Ousterhoutの法則）を避けるために正当化しドキュメント化すべきである。正しい値がわからなければ、Claudeがどうやってそれを決定できるか?

**良い例: 自己ドキュメント化**:

```typescript  theme={null}
// HTTPリクエストは通常30秒以内に完了する
// 長いタイムアウトは遅い接続に対応する
const REQUEST_TIMEOUT = 30;

// 3回のリトライで信頼性と速度のバランスを取る
// ほとんどの断続的な障害は2回目のリトライで解決する
const MAX_RETRIES = 3;
```

**悪い例: マジックナンバー**:

```typescript  theme={null}
const TIMEOUT = 47;  // なぜ47?
const RETRIES = 5;   // なぜ5?
```

### ユーティリティスクリプトを提供する

Claudeがスクリプトを書ける場合でも、既製のスクリプトには利点がある:

**ユーティリティスクリプトの利点**:

* 生成されたコードより信頼性が高い
* トークンを節約（コンテキストにコードを含める必要がない）
* 時間を節約（コード生成が不要）
* 使用間の一貫性を確保

<img src="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=4bbc45f2c2e0bee9f2f0d5da669bad00" alt="指示ファイルと並べて実行可能スクリプトをバンドル" data-og-width="2048" width="2048" data-og-height="1154" height="1154" data-path="images/agent-skills-executable-scripts.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=280&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=9a04e6535a8467bfeea492e517de389f 280w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=560&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=e49333ad90141af17c0d7651cca7216b 560w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=840&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=954265a5df52223d6572b6214168c428 840w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=1100&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=2ff7a2d8f2a83ee8af132b29f10150fd 1100w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=1650&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=48ab96245e04077f4d15e9170e081cfb 1650w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=2500&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=0301a6c8b3ee879497cc5b5483177c90 2500w" />

上の図は、実行可能スクリプトが指示ファイルとどのように連携するかを示す。指示ファイル（forms.md）がスクリプトを参照し、Claudeはコンテキストにその内容をロードせずに実行できる。

**重要な区別**: 指示の中でClaudeが以下のどちらをすべきか明確にする:

* **スクリプトを実行する**（最も一般的）: 「`analyze_form.py`を実行してフィールドを抽出する」
* **リファレンスとして読む**（複雑なロジック向け）: 「フィールド抽出アルゴリズムは`analyze_form.py`を参照」

ほとんどのユーティリティスクリプトでは、実行がより信頼性が高く効率的であるため推奨される。スクリプト実行の仕組みについては、以下の[ランタイム環境](#ランタイム環境)セクションを参照。

**例**:

````markdown  theme={null}
## ユーティリティスクリプト

**analyze_form.py**: PDFからすべてのフォームフィールドを抽出

```bash
python scripts/analyze_form.py input.pdf > fields.json
```

出力形式:
```json
{
  "field_name": {"type": "text", "x": 100, "y": 200},
  "signature": {"type": "sig", "x": 150, "y": 500}
}
```

**validate_boxes.py**: 重複するバウンディングボックスをチェック

```bash
python scripts/validate_boxes.py fields.json
# 戻り値: "OK" またはコンフリクトのリスト
```

**fill_form.py**: フィールド値をPDFに適用

```bash
python scripts/fill_form.py input.pdf fields.json output.pdf
```
````

### ビジュアル分析を使用する

入力が画像としてレンダリングできる場合、Claudeに分析させる:

````markdown  theme={null}
## フォームレイアウト分析

1. PDFを画像に変換:
   ```bash
   python scripts/pdf_to_images.py form.pdf
   ```

2. 各ページの画像を分析してフォームフィールドを特定する
3. Claudeはフィールドの位置とタイプを視覚的に確認できる
````

<Note>
  この例では、`pdf_to_images.py`スクリプトを作成する必要がある。
</Note>

Claudeの視覚能力はレイアウトと構造の理解に役立つ。

### 検証可能な中間出力を作成する

Claudeが複雑でオープンエンドなタスクを実行する場合、ミスが発生する可能性がある。「計画-検証-実行」パターンは、Claudeにまず構造化された形式で計画を作成させ、実行前にスクリプトでその計画を検証することで、早期にエラーを捕捉する。

**例**: スプレッドシートに基づいてPDFの50個のフォームフィールドを更新するようClaudeに依頼する場合を想像する。検証なしでは、Claudeは存在しないフィールドを参照したり、矛盾する値を作成したり、必須フィールドを見落としたり、更新を誤って適用したりする可能性がある。

**解決策**: 上記のワークフローパターン（PDFフォーム入力）を使用するが、変更を適用する前に検証される中間`changes.json`ファイルを追加する。ワークフローは: 分析 → **計画ファイル作成** → **計画を検証** → 実行 → 検証 となる。

**このパターンが機能する理由:**

* **早期のエラー捕捉**: 検証により変更適用前に問題を発見
* **機械検証可能**: スクリプトが客観的な検証を提供
* **可逆的な計画**: Claudeはオリジナルに触れずに計画をイテレーションできる
* **明確なデバッグ**: エラーメッセージが具体的な問題を指す

**使用タイミング**: バッチ操作、破壊的な変更、複雑なバリデーションルール、高リスクな操作。

**実装のヒント**: バリデーションスクリプトは「フィールド'signature_date'が見つかりません。利用可能なフィールド: customer_name, order_total, signature_date_signed」のような具体的なエラーメッセージで冗長にし、Claudeが問題を修正できるようにする。

### 依存関係をパッケージする

スキルはプラットフォーム固有の制限付きのコード実行環境で動作する:

* **claude.ai**: npmとPyPIからパッケージをインストールし、GitHubリポジトリからプルできる
* **Anthropic API**: ネットワークアクセスがなく、ランタイムでのパッケージインストールもできない

必要なパッケージをSKILL.mdにリストし、[コード実行ツールのドキュメント](/en/docs/agents-and-tools/tool-use/code-execution-tool)で利用可能であることを確認する。

### ランタイム環境

スキルはファイルシステムアクセス、bashコマンド、コード実行機能を持つコード実行環境で動作する。このアーキテクチャの概念的な説明については、概要の[スキルアーキテクチャ](/en/docs/agents-and-tools/agent-skills/overview#the-skills-architecture)を参照。

**執筆への影響:**

**Claudeがスキルにアクセスする方法:**

1. **メタデータのプリロード**: 起動時に、すべてのスキルのYAMLフロントマターからnameとdescriptionがシステムプロンプトにロードされる
2. **オンデマンドでファイルを読む**: Claudeは必要に応じてbash Readツールを使ってSKILL.mdやその他のファイルにファイルシステムからアクセスする
3. **効率的なスクリプト実行**: ユーティリティスクリプトは内容全体をコンテキストにロードせずにbash経由で実行できる。スクリプトの出力のみがトークンを消費する
4. **大きなファイルのコンテキストペナルティなし**: リファレンスファイル、データ、ドキュメントは実際に読まれるまでコンテキストトークンを消費しない

* **ファイルパスが重要**: Claudeはスキルディレクトリをファイルシステムとしてナビゲートする。バックスラッシュではなくスラッシュ（`reference/guide.md`）を使用する
* **ファイル名を説明的にする**: コンテンツを示す名前を使う: `form_validation_rules.md`であって`doc2.md`ではない
* **発見しやすく構成する**: ドメインまたは機能でディレクトリを構造化する
  * 良い: `reference/finance.md`, `reference/sales.md`
  * 悪い: `docs/file1.md`, `docs/file2.md`
* **包括的なリソースをバンドルする**: 完全なAPIドキュメント、広範な例、大規模なデータセットを含める; アクセスされるまでコンテキストペナルティはない
* **決定的な操作にはスクリプトを優先する**: Claudeにバリデーションコードを生成させるのではなく`validate_form.py`を書く
* **実行の意図を明確にする**:
  * 「`analyze_form.py`を実行してフィールドを抽出する」（実行）
  * 「抽出アルゴリズムは`analyze_form.py`を参照」（リファレンスとして読む）
* **ファイルアクセスパターンをテストする**: 実際のリクエストでテストして、Claudeがディレクトリ構造をナビゲートできることを確認する

**例:**

```
bigquery-skill/
├── SKILL.md (概要、リファレンスファイルへのポインター)
└── reference/
    ├── finance.md (収益指標)
    ├── sales.md (パイプラインデータ)
    └── product.md (使用分析)
```

ユーザーが収益について質問すると、ClaudeはSKILL.mdを読み、`reference/finance.md`への参照を見て、bashを使ってそのファイルだけを読む。sales.mdとproduct.mdはファイルシステムに残り、必要になるまでコンテキストトークンをゼロ消費する。このファイルシステムベースのモデルが段階的開示を可能にする。Claudeは各タスクが必要とするものだけをナビゲートして選択的にロードできる。

技術アーキテクチャの完全な詳細については、スキル概要の[スキルの仕組み](/en/docs/agents-and-tools/agent-skills/overview#how-skills-work)を参照。

### MCPツールの参照

スキルがMCP（Model Context Protocol）ツールを使用する場合、「ツールが見つかりません」エラーを避けるため、常に完全修飾ツール名を使用する。

**形式**: `ServerName:tool_name`

**例**:

```markdown  theme={null}
BigQuery:bigquery_schemaツールを使用してテーブルスキーマを取得する。
GitHub:create_issueツールを使用してイシューを作成する。
```

ここで:

* `BigQuery`と`GitHub`はMCPサーバー名
* `bigquery_schema`と`create_issue`はそれらのサーバー内のツール名

サーバープレフィックスなしでは、特に複数のMCPサーバーが利用可能な場合、Claudeがツールを見つけられない可能性がある。

### ツールがインストール済みと仮定しない

パッケージが利用可能と仮定しない:

````markdown  theme={null}
**悪い例: インストール済みと仮定**:
「pdfライブラリを使用してファイルを処理する。」

**良い例: 依存関係を明示**:
「必要なパッケージをインストール: `pip install pypdf`

その後使用する:
```typescript
import { PdfReader } from 'pypdf';
const reader = new PdfReader("file.pdf");
```」
````

## 技術的な注意事項

### YAMLフロントマターの要件

SKILL.mdのフロントマターには`name`（最大64文字）と`description`（最大1024文字）フィールドのみが含まれる。完全な構造の詳細については、[スキル概要](/en/docs/agents-and-tools/agent-skills/overview#skill-structure)を参照。

### トークン予算

最適なパフォーマンスのため、SKILL.mdの本文は500行以内に保つ。コンテンツがこれを超える場合は、前述の段階的開示パターンを使用して別ファイルに分割する。アーキテクチャの詳細については、[スキル概要](/en/docs/agents-and-tools/agent-skills/overview#how-skills-work)を参照。

## 効果的なスキルのチェックリスト

スキルを共有する前に確認する:

### コア品質

* [ ] descriptionが具体的でキーとなる用語を含んでいる
* [ ] descriptionにスキルの機能と使用タイミングの両方が含まれている
* [ ] SKILL.mdの本文が500行以内
* [ ] 追加の詳細が別ファイルにある（必要な場合）
* [ ] 時間に依存する情報がない（または「旧パターン」セクションにある）
* [ ] 全体を通じて一貫した用語
* [ ] 例が具体的で、抽象的でない
* [ ] ファイル参照が1階層
* [ ] 段階的開示が適切に使用されている
* [ ] ワークフローが明確なステップを持つ

### コードとスクリプト

* [ ] スクリプトがClaudeに丸投げせず問題を解決する
* [ ] エラーハンドリングが明示的で有用
* [ ] 「呪いの定数」がない（すべての値が正当化されている）
* [ ] 必要なパッケージが指示にリストされ、利用可能であることが確認されている
* [ ] スクリプトに明確なドキュメントがある
* [ ] Windowsスタイルのパスがない（すべてスラッシュ）
* [ ] 重要な操作にバリデーション/検証ステップがある
* [ ] 品質が重要なタスクにフィードバックループが含まれている

### テスト

* [ ] 少なくとも3つの評価が作成されている
* [ ] Haiku、Sonnet、Opusでテスト済み
* [ ] 実際の使用シナリオでテスト済み
* [ ] チームのフィードバックが取り入れられている（該当する場合）

## 次のステップ

<CardGroup cols={2}>
  <Card title="Agent Skillsを始める" icon="rocket" href="/en/docs/agents-and-tools/agent-skills/quickstart">
    最初のスキルを作成する
  </Card>

  <Card title="Claude Codeでスキルを使う" icon="terminal" href="/en/docs/claude-code/skills">
    Claude Codeでスキルを作成・管理する
  </Card>

  <Card title="APIでスキルを使う" icon="code" href="/en/api/skills-guide">
    プログラムでスキルをアップロード・使用する
  </Card>
</CardGroup>
