# 初期メモリセットの例

プロジェクトオンボーディング後に作成する初期メモリセットの構成例。

## シナリオ: E コマースプラットフォーム（Node.js/TypeScript）

### 推奨メモリ構成

| メモリ名 | 内容 |
|----------|------|
| `project-structure` | リポジトリレイアウト・レイヤー構造・インポート規約 |
| `api-conventions` | レスポンス形式・ルート構造・認証・エラーハンドリング |
| `database-schema` | ORM・コアテーブル・モデル規約・マイグレーションコマンド |
| `testing-patterns` | フレームワーク・テスト構造・コマンド・カバレッジ要件 |
| `build-and-deployment` | ビルドコマンド・環境変数・デプロイ手順 |

---

### 例1: `project-structure`（ツリー構造 + パターン型）

```markdown
# プロジェクト構造と組織

## リポジトリレイアウト

ecommerce-platform/
├── src/
│   ├── api/           # REST API endpoints (Express routes)
│   ├── services/      # Business logic layer
│   ├── models/        # Database models (Sequelize)
│   ├── middleware/     # Express middleware
│   ├── utils/         # Shared utilities
│   └── types/         # TypeScript type definitions
├── tests/
│   ├── unit/          # Unit tests for services
│   ├── integration/   # API integration tests
│   └── fixtures/      # Test data
├── migrations/        # Database migrations (Sequelize)
└── scripts/           # Deployment and utility scripts

## 主要パターン

- **レイヤードアーキテクチャ:** API → Services → Models
- **ルートにビジネスロジックを置かない:** ルートは HTTP に関する処理のみ
- **依存性注入:** Services はコンストラクタ経由で依存を受け取る
- **型の集約:** すべての TypeScript 型は src/types/ に集中管理

## インポート規約

    import { UserService } from '@/services/UserService';  // tsconfig paths

## 根拠

レイヤードアーキテクチャにより HTTP 層なしにビジネスロジックのテストが可能。
```

### 例2: `api-conventions`（コード例 + 規約型）

```markdown
# API 規約とパターン

## レスポンス形式

    { status: number, data?: any, error?: { code: string, message: string, details?: object } }

## ルートパターン

    // src/api/routes/users.ts
    router.get('/:id', authenticate, async (req, res, next) => {
      try {
        const user = await userService.getById(req.params.id);
        res.json({ status: 200, data: user });
      } catch (error) {
        next(error); // → src/middleware/errorHandler.ts
      }
    });

## 認証

`src/middleware/auth.ts` の `authenticate` ミドルウェア。JWT トークンを検証。

## エラーハンドリング

`src/middleware/errorHandler.ts` に集約。ルート・サービスでスローし、ミドルウェアがキャッチ。
```

---

## 良い初期メモリセットのポイント

- **トピック別に1メモリ:** ランダムなメモの羅列にしない
- **具体的:** ファイルパス・コード例・正確なコマンドを含む
- **根拠を含む:** パターンが存在する理由を説明する
- **適切なスコープ:** 5つ前後 — 圧倒せずに十分な詳細
