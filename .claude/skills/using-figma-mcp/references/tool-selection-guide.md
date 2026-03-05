# Figma MCP ツール詳細リファレンス

## get_design_context

**対応ファイル:** Figma Design, Figma Make

構造化されたデザインコンテキストを取得する。デフォルト出力はReact + Tailwindだが、**本プロジェクトではFlutter/Dart Widgetに変換して使用する。**

**使うとき:**
- フレームやコンポーネントからFlutter Widgetコードを生成したい
- デザインのレイアウト・スタイル情報が必要

**Flutter変換の流れ:**
1. `get_design_context` でReact+Tailwind出力を取得
2. レイアウト構造を `Column` / `Row` / `Stack` 等のFlutter Widgetに変換
3. Tailwindクラスを `TextStyle` / `BoxDecoration` / `EdgeInsets` 等に変換
4. プロジェクト既存の `AppColors` / フォント定数を優先使用

**注意:** 大規模デザインではレスポンスが巨大化する。先に `get_metadata` で構造把握し、必要なノードのみ取得する。

---

## get_metadata

**対応ファイル:** Figma Design

選択範囲のXML表現を返す。レイヤーID、名前、タイプ、位置、サイズなどの基本プロパティを含む。

**使うとき:**
- 大規模デザインの全体構造を軽量に把握したい
- `get_design_context` の出力が大きすぎる/切り詰められた場合
- ページ全体のノードマップが欲しい（何も選択していない場合はページ全体を返す）

**ワークフロー:**
1. `get_metadata` で全体のノードIDとタイプを取得
2. 必要なノードIDを特定
3. `get_design_context` で必要ノードのみ詳細取得

---

## get_screenshot

**対応ファイル:** Figma Design, FigJam

選択範囲のスクリーンショットを取得する。

**使うとき:**
- レイアウト忠実性を視覚的に確認したい
- 実装結果とデザインを比較したい
- get_design_context だけでは把握しにくいビジュアル要素がある

**注意:** トークン制限が気にならない限り、常に有効にしておくとよい。

---

## get_variable_defs

**対応ファイル:** Figma Design

選択範囲で使用されている変数とスタイル（色、スペーシング、タイポグラフィ）を返す。

**使うとき:**
- デザイントークンの名前と値を知りたい
- ハードコード値の代わりにトークンを使いたい
- 特定の種類のトークン（色のみ、スペーシングのみ）を取得したい

**プロンプト例:**
- 「このFigma選択の変数を取得して」
- 「色とスペーシングの変数を教えて」
- 「変数名とその値をリストして」

---

## get_code_connect_map

**対応ファイル:** Figma Design

FigmaノードIDとコードベースのコンポーネントのマッピングを返す。

**返却値:**
- `codeConnectSrc`: コードベース内のコンポーネントパス
- `codeConnectName`: コンポーネント名

**使うとき:**
- Figmaのデザイン要素に対応するコードコンポーネントを特定したい
- 既存コンポーネントの再利用を確認したい

---

## add_code_connect_map

**対応ファイル:** Figma Design

FigmaノードIDとコードコンポーネントのマッピングを作成する。

**使うとき:**
- デザイン要素とコード実装を明示的にリンクしたい
- Code Connect を新規設定したい

**注意:** レート制限の対象外（書き込み系ツール）。

---

## get_code_connect_suggestions / send_code_connect_mappings

**対応ファイル:** Figma Design

2ステップのワークフロー:
1. `get_code_connect_suggestions` でFigmaコンポーネントとコードコンポーネントの対応候補を検出
2. `send_code_connect_mappings` で候補を確認・確定

---

## get_figjam

**対応ファイル:** FigJam

FigJam図のメタデータをXML形式で返す。`get_metadata` と同様の基本プロパティに加え、ノードのスクリーンショットも含む。

---

## create_design_system_rules

**対応ファイル:** ファイルコンテキスト不要

リポジトリ向けのデザインシステムルールを生成するためのプロンプトを提供する。

**使うとき:**

- プロジェクトのデザインシステムルールを作成・更新したい
- Figmaデザインとコードベースの一貫性を確保したい

---

## React+Tailwind → Flutter/Dart 変換対応表

`get_design_context` のデフォルト出力はReact + Tailwindだが、**本プロジェクトではFlutter/Dartに変換して使用する。**

| React + Tailwind (MCP出力) | Flutter/Dart (変換後) |
| --------------------------- | ---------------------- |
| `<div>` + flexbox | `Column` / `Row` / `Stack` |
| `<div>` + padding/margin | `Padding` / `SizedBox` / `EdgeInsets` |
| `<span>` / `<p>` + text styles | `Text` + `TextStyle` |
| `<img src="...">` | `Image.network()` / `Image.asset()` |
| `<svg>` | `SvgPicture.network()` / カスタムアイコン |
| `border-radius` | `BorderRadius.circular()` |
| `box-shadow` | `BoxShadow` in `BoxDecoration` |
| `gap` (flexbox) | `SizedBox` between children / `MainAxisAlignment.spaceBetween` |
| `overflow: scroll` | `SingleChildScrollView` / `ListView` |
| `position: absolute` | `Positioned` in `Stack` |
| `background: linear-gradient(...)` | `LinearGradient` in `BoxDecoration` |
| `opacity` | `Opacity` widget / `Color.withOpacity()` |

**変換ルール:**

- Figmaの色値 → プロジェクト既存の `AppColors` 定数を優先使用
- Figmaのフォント → プロジェクト既存の `TextStyle` 定数を優先使用
- Figmaのスペーシング → プロジェクト既存の定数を優先使用
- AutoLayout → `Row` / `Column` + `MainAxisAlignment` / `CrossAxisAlignment`
- Figmaコンポーネント → プロジェクト既存Widgetがあれば再利用
- localhost画像URL → `Image.network('http://localhost:...')` でそのまま使用
