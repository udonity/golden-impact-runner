# 良いメモリの例: API エラーハンドリング規約

この例は、具体的な詳細・ファイルパス・根拠を含む、構造化された実用的なメモリコンテンツを示している。

## 目次

1. [コンテキスト](#コンテキスト)
2. [レスポンス形式](#レスポンス形式)
3. [実装場所](#実装場所)
4. [エラーコード規約](#エラーコード規約)
5. [カスタムエラークラス](#カスタムエラークラス)
6. [根拠](#根拠)
7. [関連情報](#関連情報)
8. [フロントエンド統合](#フロントエンド統合)
9. [なぜこれが良いメモリか](#なぜこれが良いメモリか)

---

# API エラーハンドリング規約

## コンテキスト

このプロジェクトの REST API は全エンドポイントで標準化されたエラーレスポンスを使用する。一貫性を確保するため、すべてのエラーハンドリングロジックはミドルウェアに集約されている。

## レスポンス形式

すべての API エラーは一貫した JSON 構造を返す:

```json
{
  "status": 400,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable description",
    "details": {
      "field": "specific_field",
      "value": "invalid_value"
    }
  }
}
```

- `status`: HTTP ステータスコード（数値）
- `error.code`: 機械可読のエラーコード（大文字スネークケース）
- `error.message`: 人間が読める説明文
- `error.details`: 追加コンテキストを持つオプションのオブジェクト

## 実装場所

**主要ファイル:** `src/middleware/errorHandler.ts`

エラーミドルウェアはすべての投げられた例外を捕捉してフォーマットする:

```typescript
// src/middleware/errorHandler.ts
export function errorHandler(err: Error, req: Request, res: Response, next: NextFunction) {
  if (err instanceof ValidationError) {
    return res.status(400).json({
      status: 400,
      error: {
        code: 'INVALID_INPUT',
        message: err.message,
        details: err.fields
      }
    });
  }
  
  if (err instanceof AuthenticationError) {
    return res.status(401).json({
      status: 401,
      error: {
        code: 'UNAUTHORIZED',
        message: 'Authentication required'
      }
    });
  }
  
  // Default 500 error
  return res.status(500).json({
    status: 500,
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred'
    }
  });
}
```

## エラーコード規約

すべてのエラーコードはこのパターンに従う:

| コード | HTTP ステータス | 用途 |
|------|-------------|-------|
| `INVALID_INPUT` | 400 | バリデーション失敗 |
| `UNAUTHORIZED` | 401 | 認証なしまたは無効な認証 |
| `FORBIDDEN` | 403 | 権限不足 |
| `NOT_FOUND` | 404 | リソースが存在しない |
| `CONFLICT` | 409 | リソース状態の競合（例: メール重複） |
| `INTERNAL_ERROR` | 500 | 予期しないサーバーエラー |

**ファイル場所:** エラーコードは `src/constants/errorCodes.ts` に定数として定義されている

## カスタムエラークラス

このプロジェクトはタイプセーフなエラーハンドリングを実現するためにカスタムエラークラスを使用する:

```typescript
// src/errors/ValidationError.ts
export class ValidationError extends Error {
  constructor(
    message: string,
    public fields: Record<string, string>
  ) {
    super(message);
    this.name = 'ValidationError';
  }
}

// Usage in route handlers:
if (!isValidEmail(email)) {
  throw new ValidationError('Invalid email format', {
    field: 'email',
    value: email
  });
}
```

**ファイル:**

- `src/errors/ValidationError.ts`
- `src/errors/AuthenticationError.ts`
- `src/errors/NotFoundError.ts`

## 根拠

**このパターンを採用している理由:**

1. **一貫したクライアント体験:** フロントエンドはエンドポイントごとの特別処理なしに汎用エラーハンドリングを実装できる
2. **型安全性:** カスタムエラークラスにより TypeScript の型チェックが有効になる
3. **デバッグしやすさ:** エラーコードによりログでの素早い特定が可能
4. **国際化対応:** 機械可読コードをクライアントサイドでローカライズされたメッセージにマッピングできる

**歴史的コンテキスト:** このパターンはルート全体で一貫性のないエラーレスポンスを置き換えるために v2.0 リファクタリング (commit abc123) で採用された。

## 関連情報

- 認証ロジック: `authentication-flow.md` メモリを参照
- バリデーションパターン: `input-validation.md` メモリを参照
- ロギング: エラーは `src/middleware/logger.ts` に記録される

## フロントエンド統合

フロントエンドはこのパターンでエラーを処理する:

```typescript
// Frontend error handling (for reference)
try {
  await api.createUser(data);
} catch (error) {
  if (error.response?.data?.error?.code === 'INVALID_INPUT') {
    // Show field-specific validation errors
    showValidationErrors(error.response.data.error.details);
  } else {
    // Show generic error message
    showErrorToast(error.response.data.error.message);
  }
}
```

---

## なぜこれが良いメモリか

✅ **具体的:** 正確なファイルパスとコード例を含む  
✅ **実用的:** 新しいエンドポイントで従うべき明確なパターンを提供  
✅ **コンテキスト付き:** 根拠と歴史的な決定を説明している  
✅ **クロスリファレンス:** 関連するメモリへのリンクあり  
✅ **構造化:** ヘッダー・テーブル・コードブロックで読みやすい  
✅ **スコープ適切:** 一つのまとまったトピック（エラーハンドリング）をカバー  
