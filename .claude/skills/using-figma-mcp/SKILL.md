---
name: using-figma-mcp
description: Figma MCPサーバーの各ツール（get_design_context、get_variable_defs、get_metadata、get_screenshot等）を正しく選択・使用するためのリファレンスガイド。Figmaデザインデータの取得戦略、アセットの扱い方、ツール選択の判断が必要な際にトリガーされる。FigmaフレームURLからのコード実装生成にはfigma-conservative-recursiveを使用すること。
---

# Using Figma MCP

Figma MCPサーバーの各ツールを正しく選択・使用するためのリファレンスガイド。

**基本原則:** 目的に合ったツールを選び、小さい単位で取得し、アセットはMCPが返すソースをそのまま使う。出力はFlutter/Dartに変換して使用する。

## 使用するタイミング

**使用する場合:**
- Figma MCPツールの呼び出しが必要なとき
- どのツールを使うべきか判断が必要なとき
- デザインデータの取得戦略を決めるとき
- アセット（画像・SVG）の扱い方を決めるとき

**使用しない場合:**
- FigmaフレームURLからコード実装を生成する → **figma-conservative-recursive** を使う
- Figma MCP と無関係な一般的なUI実装

## ツール選択クイックリファレンス

| やりたいこと | 使うツール | 注意点 |
|-------------|-----------|--------|
| フレームからコード生成 | `get_design_context` | デフォルトはReact+Tailwind出力。**本プロジェクトではFlutter/Dartに変換して使用** |
| 大規模デザインの構造把握 | `get_metadata` → 必要ノードのみ `get_design_context` | トークン節約の鍵 |
| デザインの見た目を確認 | `get_screenshot` | レイアウト忠実性の保持に有効 |
| 変数・トークンの取得 | `get_variable_defs` | 色、スペーシング、タイポグラフィ |
| コード接続の確認 | `get_code_connect_map` | Figmaノード↔コードコンポーネントのマッピング |
| コード接続の作成 | `add_code_connect_map` | デザイン要素とコード実装をリンク |
| コード接続の候補検出 | `get_code_connect_suggestions` → `send_code_connect_mappings` | 2ステップで完了 |
| FigJam図の取得 | `get_figjam` | XMLメタデータ + スクリーンショット |
| デザインシステムルール生成 | `create_design_system_rules` | リポジトリ向けルールを生成 |

ツールの選択に迷った場合やパラメータの詳細が必要な場合 → @references/tool-selection-guide.md を参照。

## 鉄則: アセット処理ルール

```
Figma MCPがlocalhost URLを返した画像・SVG → そのまま直接使用する
```

**絶対にやってはいけないこと:**
- localhostソースが提供されているのにプレースホルダーを使う
- 新しいアイコンパッケージを追加する（アセットはすべてFigmaペイロードに含まれる）
- 画像URLを推測・捏造する

## 大規模デザインの取得戦略

```
1. get_metadata で全体構造をXMLで取得（軽量）
2. 必要なノードIDを特定
3. get_design_context で必要ノードのみ詳細取得
4. get_screenshot で見た目を確認
```

**get_design_contextが大きすぎる/切り詰められた場合:**
- フレームを小さなセクションに分割して個別取得
- コンポーネント単位（Card、Header、Sidebar等）で取得

## レート制限

| プラン | 制限 |
|--------|------|
| Starter / View・Collabシート | 月6回まで |
| Dev・Fullシート（Professional以上） | Figma REST API Tier 1と同じ（分単位） |

書き込み系ツール（add_code_connect_map等）はレート制限の対象外。

## get_design_context の出力変換（Flutter/Dart）

`get_design_context` の出力はReact + Tailwindだが、**本プロジェクトではFlutter/Dartに変換して使用する。**

- React要素 → Flutter Widget（`Column`/`Row`/`Stack`/`Text`等）
- Tailwindクラス → `TextStyle`/`BoxDecoration`/`EdgeInsets`等
- 色・フォント・スペーシング → プロジェクト既存定数（`AppColors`等）を優先使用

変換対応表の詳細が必要な場合 → @references/tool-selection-guide.md の「React+Tailwind → Flutter/Dart 変換対応表」を参照。

## よくある間違い

**NG 大きなフレームをそのまま get_design_context:** レスポンスが巨大化・切り詰められる。先に get_metadata で構造把握。

**NG アセットのlocalhost URLを無視:** Figma MCPが返すlocalhost URLはそのまま使用すること。

**NG get_variable_defs を使わずにハードコード値:** デザイントークン（色・スペーシング等）はget_variable_defsで取得して使う。

**NG 全ツールを毎回呼ぶ:** 必要なツールだけ呼ぶ。レート制限あり。

**NG React+Tailwind出力をそのまま使う:** `get_design_context` の出力はReact+Tailwindだが、必ずFlutter Widgetに変換する。

**NG プロジェクト既存の定数を無視:** 色・フォント・スペーシングはプロジェクトの `AppColors` / `TextStyle` 定数を優先使用する。

## 統合

**前提条件:**
- Figma MCPサーバーが設定済み（`.vscode/mcp.json` または `claude mcp add`）

**関連スキル:**
- **figma-conservative-recursive** - フレームURLからのコード実装生成（サブエージェントパターン）
