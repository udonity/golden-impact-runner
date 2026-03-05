# 多層防御バリデーション

## 概要

不正なデータによるバグを修正する際、一箇所にバリデーションを追加すれば十分に感じる。しかし、その単一のチェックは、異なるコードパス、リファクタリング、またはモックによってバイパスされる可能性がある。

**基本原則:** データが通過するすべてのレイヤーでバリデーションを行う。バグを構造的に不可能にする。

## なぜ複数のレイヤーが必要か

単一のバリデーション: 「バグを修正した」
複数のレイヤー: 「バグを不可能にした」

異なるレイヤーは異なるケースをキャッチする:
- エントリーバリデーションはほとんどのバグをキャッチ
- ビジネスロジックはエッジケースをキャッチ
- 環境ガードはコンテキスト固有の危険を防止
- デバッグログは他のレイヤーが失敗した時に役立つ

## 4つのレイヤー

### レイヤー1: エントリーポイントバリデーション
**目的:** API境界で明らかに無効な入力を拒否する

```typescript
function createProject(name: string, workingDirectory: string) {
  if (!workingDirectory || workingDirectory.trim() === '') {
    throw new Error('workingDirectoryは空にできません');
  }
  if (!existsSync(workingDirectory)) {
    throw new Error(`workingDirectoryが存在しません: ${workingDirectory}`);
  }
  if (!statSync(workingDirectory).isDirectory()) {
    throw new Error(`workingDirectoryはディレクトリではありません: ${workingDirectory}`);
  }
  // ... 処理を続行
}
```

### レイヤー2: ビジネスロジックバリデーション
**目的:** この操作に対してデータが意味を持つことを確認する

```typescript
function initializeWorkspace(projectDir: string, sessionId: string) {
  if (!projectDir) {
    throw new Error('ワークスペースの初期化にはprojectDirが必要です');
  }
  // ... 処理を続行
}
```

### レイヤー3: 環境ガード
**目的:** 特定のコンテキストで危険な操作を防止する

```typescript
async function gitInit(directory: string) {
  // テスト時は、一時ディレクトリ外でのgit initを拒否
  if (process.env.NODE_ENV === 'test') {
    const normalized = normalize(resolve(directory));
    const tmpDir = normalize(resolve(tmpdir()));

    if (!normalized.startsWith(tmpDir)) {
      throw new Error(
        `テスト中に一時ディレクトリ外でのgit initを拒否: ${directory}`
      );
    }
  }
  // ... 処理を続行
}
```

### レイヤー4: デバッグ計装
**目的:** フォレンジクスのためにコンテキストをキャプチャする

```typescript
async function gitInit(directory: string) {
  const stack = new Error().stack;
  logger.debug('git initを実行しようとしています', {
    directory,
    cwd: process.cwd(),
    stack,
  });
  // ... 処理を続行
}
```

## パターンの適用

バグを発見したら:

1. **データフローをトレースする** - 不正な値はどこで発生し、どこで使用されるか？
2. **すべてのチェックポイントをマッピングする** - データが通過するすべてのポイントをリストアップ
3. **各レイヤーにバリデーションを追加する** - エントリー、ビジネス、環境、デバッグ
4. **各レイヤーをテストする** - レイヤー1をバイパスし、レイヤー2がキャッチするか確認

## セッションからの例

バグ: 空の `projectDir` により `git init` がソースコード内で実行された

**データフロー:**
1. テストセットアップ → 空文字列
2. `Project.create(name, '')`
3. `WorkspaceManager.createWorkspace('')`
4. `git init` が `process.cwd()` で実行される

**追加した4つのレイヤー:**
- レイヤー1: `Project.create()` が空でない/存在する/書き込み可能を検証
- レイヤー2: `WorkspaceManager` がprojectDirが空でないことを検証
- レイヤー3: `WorktreeManager` がテスト時にtmpdir外でのgit initを拒否
- レイヤー4: git init前のスタックトレースログ

**結果:** 1847件のテストすべてが合格、バグの再現が不可能に

## 主な知見

4つのレイヤーすべてが必要だった。テスト中、各レイヤーが他のレイヤーでは見逃されるバグをキャッチした:
- 異なるコードパスがエントリーバリデーションをバイパス
- モックがビジネスロジックチェックをバイパス
- 異なるプラットフォームのエッジケースに環境ガードが必要
- デバッグログが構造的な誤用を特定

**一箇所のバリデーションで止まらないこと。** すべてのレイヤーにチェックを追加する。
