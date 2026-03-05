# Golden Impact Runner

Git差分から影響を受けるFlutter Golden Testを特定するCLIツール。

変更ファイルをimport依存グラフで逆引きし、再実行が必要なGolden Testだけを絞り込みます。

## インストール

### GitHubから

```bash
dart pub global activate --source git https://github.com/th/golden-impact-runner.git
```

### ローカル（開発用）

```bash
git clone https://github.com/th/golden-impact-runner.git
cd golden-impact-runner
dart pub global activate --source path .
```

## 使い方

### 基本（mainブランチとの差分から影響Golden Testを列挙）

```bash
golden_impact_runner
```

### オプション

```
--base <branch>     比較元ブランチ (default: origin/main)
--head <ref>        比較先ref (default: HEAD)
--changed <file>    変更ファイルを直接指定（繰り返し可、what-if分析用）
--project <dir>     プロジェクトルート (default: カレントディレクトリ)
--format <fmt>      出力形式: text, json, command (default: text)
--exclude <pattern> globパターンでファイルを除外（繰り返し可）
--verbose, -v       診断情報をstderrに出力
--help, -h          ヘルプを表示
```

### 例

```bash
# ブランチ指定
golden_impact_runner --base origin/develop --head feature/my-change

# 特定ファイルを変更したと仮定して影響を見る（what-if）
golden_impact_runner --changed lib/widgets/button.dart

# JSON出力
golden_impact_runner --format json

# CI連携: flutter test コマンドを直接出力
golden_impact_runner --format command
# => flutter test test/widgets/button_golden_test.dart test/screens/home_golden_test.dart

# 特定ディレクトリを除外
golden_impact_runner --exclude '**/generated/**' --exclude '**/*.mocks.dart'

# 詳細出力（依存グラフ統計など）
golden_impact_runner --verbose
```

### CI連携

GitHub Actionsなどで、影響のあるGolden Testだけを実行:

```yaml
- name: Run impacted golden tests
  run: |
    cmd=$(golden_impact_runner --format command)
    if [ -n "$cmd" ]; then
      $cmd
    else
      echo "No golden tests affected."
    fi
```

## 出力形式

### text（デフォルト）

影響テストのパスを1行1ファイルで出力:

```
test/widgets/button_golden_test.dart
test/screens/home_screen_golden_test.dart
```

### json

変更ファイル・影響ファイル・Golden Testを構造化して出力:

```json
{
  "changed_files": ["lib/widgets/button.dart"],
  "impacted_files": ["lib/screens/home_screen.dart", "lib/widgets/button.dart"],
  "golden_tests": ["test/widgets/button_golden_test.dart"]
}
```

### command

`flutter test` コマンドをそのまま出力（影響テスト0件の場合は何も出力しない）:

```
flutter test test/widgets/button_golden_test.dart test/screens/home_golden_test.dart
```

## 仕組み

1. `git diff` で変更された `.dart` ファイルを取得
2. 生成ファイル（`.g.dart` / `.freezed.dart` / `.gr.dart`）を元ファイルに正規化
3. プロジェクト内の全 `.dart` ファイルから `import` / `export` / `part` を解析し依存グラフを構築
4. 変更ファイルを起点にBFSで逆依存を探索
5. 到達したファイルのうち `matchesGoldenFile` 等を含むテストファイルを抽出

### 対応するGolden Testパターン

- `matchesGoldenFile(` — 標準 Flutter
- `goldenTest(` / `GoldenTestGroup(` / `GoldenTestScenario(` — Alchemist

### 対応するimportパターン

- `package:` import（自パッケージのみ追跡、外部パッケージは無視）
- 相対パス import
- `export` / `part` / `part of`
- conditional import（`if (dart.library.*)`）
- deferred import（`deferred as`）

## 制約事項

### 依存追跡の範囲

- **外部パッケージ経由の依存は追跡しない** — `package:` importのうち自パッケージのみ追跡。モノレポでのcross-package依存は未対応
- **走査対象は `lib/` と `test/` のみ** — `bin/`、`example/`、`integration_test/` 内のGolden Testは検出対象外
- **暗黙的な依存は追跡不可** — Theme/Style変更（`Theme.of(context)`）、アセットファイル変更、`build.yaml` やpubspec.yamlの依存バージョン変更など

### 解析の精度

- **ファイル単位の依存追跡** — Widget単位の精密な解析ではないため、同一ファイル内の無関係なWidgetの変更でもGolden Testが影響ありと判定される（オーバー検出の可能性あり）
- **Golden Test検出パターンは固定** — `matchesGoldenFile(`・Alchemist系の4パターンのみ。独自ヘルパー関数でラップしている場合は検出できない
- **コメント除去が簡易実装** — 文字列リテラル内の `//` や `/*` もコメントとして除去されるため、稀に誤検出の可能性あり

これらの制約はPhase 2以降で段階的に改善予定です。詳細は [TODO.md](TODO.md) を参照してください。

## 開発

```bash
# テスト実行
dart test

# 静的解析
dart analyze

# ローカル実行
dart run golden_impact_runner --project /path/to/flutter/project
```

## ライセンス

MIT
