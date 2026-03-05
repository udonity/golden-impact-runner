# Phase 1.5: CI実用化 — デザインドキュメント

## 背景

Phase 1（ファイルレベルMVP）が完了。次のゴールは **GitHub Actions上でこのツールを使い、影響のあるGolden Testだけを実行する** こと。

Widget単位の精度向上（Phase 2）より先に、CI組み込みに必要な機能を優先する。Actions側のワークフロー定義はユーザーが自由に組むため、テンプレートやPRコメントBotは不要。ツール側の出力機能を充実させる。

## スコープ

### 1. 生成ファイル対応

**課題**: 実プロジェクトでは `build_runner` による生成ファイル（`.g.dart`, `.freezed.dart` 等）が大量に存在する。これらが変更された場合、元ファイルの変更として扱う必要がある。

**設計**:
- `<name>.<suffix>.dart` が変更された場合、同ディレクトリの `<name>.dart` が存在すればそちらを変更ファイルとして扱う
- 元ファイルが存在しない場合は、生成ファイル自体を変更ファイルとして扱う（フォールバック）

**対応サフィックス（ハードコード）**:
- `.g.dart` — json_serializable, built_value
- `.freezed.dart` — freezed
- `.gr.dart` — auto_route

**実装箇所**: `DiffProvider` または `Runner` で変更ファイル一覧を受け取った後に正規化する。

### 2. `--format command` 出力

**課題**: CI上で `flutter test <影響ファイル>` を直接実行したい。

**設計**:
- `--format` に `command` を追加（既存: `text`, `json`）
- 影響テストがある場合: `flutter test test/a.dart test/b.dart` を出力
- 影響テストがない場合: 空文字列を出力（何も実行しない）

**CI上での使用例**:
```yaml
- run: |
    cmd=$(golden_impact_runner --format command --base origin/main)
    if [ -n "$cmd" ]; then
      $cmd
    fi
```

### 3. 終了コード

| 状況 | 終了コード |
|------|-----------|
| 影響テストあり（正常出力） | 0 |
| 影響テストなし | 0 |
| エラー（git失敗、プロジェクト不正等） | 1 |

## スコープ外

- GitHub Actions ワークフローテンプレート
- PRコメントBot
- Widget単位の依存解析（Phase 2）
- インクリメンタルキャッシュ（Phase 3）
