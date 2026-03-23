# Supabase セットアップ手順

## 実行順序

Supabase Dashboard の **SQL Editor** で以下の順番にファイルを実行してください。

| 順序 | ファイル | 内容 |
|------|---------|------|
| 1 | `migrations/00001_create_tables.sql` | テーブル定義 |
| 2 | `migrations/00002_create_indexes.sql` | インデックス |
| 3 | `migrations/00003_create_triggers.sql` | トリガー（プロフィール自動作成・updated_at自動更新） |
| 4 | `migrations/00004_create_rls.sql` | Row Level Security ポリシー |
| 5 | `seed.sql` | デフォルトカテゴリーの初期データ |

## Supabase Dashboard へのアクセス

1. [supabase.com](https://supabase.com) にログイン
2. プロジェクトを選択
3. 左メニュー **SQL Editor** → **New query**
4. 各ファイルの内容をコピー&ペーストして **Run** を実行

## iOSアプリへの接続情報の確認場所

左メニュー **Settings** → **API**

| 項目 | Xcode 環境変数名 |
|------|----------------|
| Project URL | `SUPABASE_URL` |
| anon public key | `SUPABASE_ANON_KEY` |

## Auth の設定（推奨）

左メニュー **Authentication** → **Providers**

- **Email**: 有効（デフォルト）
- **Apple**: v1.1以降に設定
