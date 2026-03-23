# データモデル設計書

**プロジェクト名**: SubTrack Family（仮称）
**作成日**: 2026-03-23
**バージョン**: 1.0

---

## 1. ER 図（概念）

```
┌─────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│    profiles     │       │  group_members   │       │     groups       │
│─────────────────│       │──────────────────│       │──────────────────│
│ id (PK)         │◄──────│ user_id (FK)     │───────►│ id (PK)          │
│ email           │  1:N  │ group_id (FK)    │  N:1  │ name             │
│ display_name    │       │ role             │       │ owner_id (FK)    │
│ base_currency   │       │ joined_at        │       │ invite_code      │
│ avatar_url      │       └──────────────────┘       │ created_at       │
│ created_at      │                                   └────────┬─────────┘
│ updated_at      │◄──────────────────────────────────────────┤
└─────────────────┘                                            │ 1:N
        │                                                      ▼
        │                                           ┌──────────────────────┐
        │                                           │    subscriptions     │
        │                                           │──────────────────────│
        │                                           │ id (PK)              │
        └───────────────────────────────────────────► contractor_user_id   │
                                                    │ group_id (FK)        │
                                                    │ name                 │
                                                    │ amount               │
                                                    │ currency             │
                                                    │ billing_cycle        │
                                                    │ next_billing_date    │
                                                    │ status               │
                                                    │ category_id (FK)     │
                                                    │ is_important         │
                                                    │ ...                  │
                                                    └──────┬───────────────┘
                                                           │ 1:N
                            ┌──────────────────┐          │
                            │   categories     │◄─────────┘
                            │──────────────────│
                            │ id (PK)          │
                            │ name             │
                            │ icon             │
                            │ color            │
                            │ is_default       │
                            └──────────────────┘

┌────────────────────────┐       ┌─────────────────────┐
│  notification_settings │       │   device_tokens      │
│────────────────────────│       │─────────────────────│
│ id (PK)                │       │ id (PK)              │
│ subscription_id (FK)   │       │ user_id (FK)         │
│ user_id (FK)           │       │ token                │
│ notify_days_before[]   │       │ platform             │
│ is_enabled             │       │ created_at           │
└────────────────────────┘       └─────────────────────┘

┌─────────────────────────┐
│    exchange_rates        │
│─────────────────────────│
│ base_currency (PK)       │
│ target_currency (PK)     │
│ rate                     │
│ fetched_at               │
└─────────────────────────┘
```

---

## 2. テーブル定義

### 2.1 profiles（ユーザープロフィール）

Supabase Auth の `auth.users` テーブルを拡張したテーブル。

```sql
CREATE TABLE public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name  TEXT NOT NULL,
  avatar_url    TEXT,
  base_currency TEXT NOT NULL DEFAULT 'JPY',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ユーザー作成時に自動でprofileを作成するトリガー
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

| カラム | 型 | 説明 |
|--------|-----|------|
| id | UUID | auth.users.id と同じ（主キー） |
| display_name | TEXT | 表示名 |
| avatar_url | TEXT | アバター画像URL（nullable） |
| base_currency | TEXT | 基準通貨コード（例: "JPY"） |
| created_at | TIMESTAMPTZ | 作成日時 |
| updated_at | TIMESTAMPTZ | 更新日時 |

### 2.2 groups（家族グループ）

```sql
CREATE TABLE public.groups (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  owner_id    UUID NOT NULL REFERENCES public.profiles(id),
  invite_code TEXT UNIQUE DEFAULT encode(gen_random_bytes(6), 'hex'),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

| カラム | 型 | 説明 |
|--------|-----|------|
| id | UUID | グループID（主キー） |
| name | TEXT | グループ名（例: "田中家"） |
| owner_id | UUID | グループオーナーのユーザーID |
| invite_code | TEXT | 招待コード（ランダム12文字） |
| created_at | TIMESTAMPTZ | 作成日時 |

### 2.3 group_members（グループメンバー）

```sql
CREATE TABLE public.group_members (
  group_id  UUID REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id   UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  role      TEXT NOT NULL DEFAULT 'member'
              CHECK (role IN ('owner', 'member', 'viewer')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (group_id, user_id)
);
```

| カラム | 型 | 説明 |
|--------|-----|------|
| group_id | UUID | グループID（複合主キー） |
| user_id | UUID | ユーザーID（複合主キー） |
| role | TEXT | ロール: `owner` / `member` / `viewer` |
| joined_at | TIMESTAMPTZ | 参加日時 |

### 2.4 categories（カテゴリー）

```sql
CREATE TABLE public.categories (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  icon       TEXT,       -- SF Symbols name（例: "tv.fill"）
  color      TEXT,       -- HEX カラーコード（例: "#FF5733"）
  is_default BOOLEAN NOT NULL DEFAULT FALSE
);

-- デフォルトカテゴリーの挿入
INSERT INTO public.categories (name, icon, color, is_default) VALUES
  ('エンタメ',         'tv.fill',           '#E74C3C', TRUE),
  ('音楽',             'music.note',        '#9B59B6', TRUE),
  ('クラウドストレージ', 'icloud.fill',       '#3498DB', TRUE),
  ('ビジネス・仕事',    'briefcase.fill',    '#2ECC71', TRUE),
  ('ニュース・情報',    'newspaper.fill',    '#F39C12', TRUE),
  ('ゲーム',           'gamecontroller.fill','#1ABC9C', TRUE),
  ('学習・教育',        'book.fill',         '#D35400', TRUE),
  ('ヘルス・フィットネス','heart.fill',       '#E91E63', TRUE),
  ('セキュリティ',      'lock.shield.fill',  '#607D8B', TRUE),
  ('その他',           'tag.fill',          '#95A5A6', TRUE);
```

| カラム | 型 | 説明 |
|--------|-----|------|
| id | UUID | カテゴリーID（主キー） |
| name | TEXT | カテゴリー名 |
| icon | TEXT | SF Symbols アイコン名 |
| color | TEXT | テーマカラー（HEX） |
| is_default | BOOLEAN | デフォルトカテゴリーかどうか |

### 2.5 subscriptions（サブスクリプション）

```sql
CREATE TABLE public.subscriptions (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id             UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,

  -- 基本情報
  name                 TEXT NOT NULL,
  description          TEXT,
  category_id          UUID REFERENCES public.categories(id),
  status               TEXT NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active', 'trial', 'inactive', 'cancelled')),
  service_url          TEXT,

  -- 契約情報（相続対応）
  contractor_user_id   UUID REFERENCES public.profiles(id),
  payment_method_note  TEXT,     -- 例: "JCBカード（末尾1234）" ※実際のカード番号は保存しない
  is_important         BOOLEAN NOT NULL DEFAULT FALSE,

  -- 請求情報
  amount               DECIMAL(12, 2) NOT NULL,
  currency             TEXT NOT NULL DEFAULT 'JPY',
  billing_cycle        TEXT NOT NULL DEFAULT 'monthly'
                         CHECK (billing_cycle IN (
                           'daily', 'weekly', 'monthly',
                           'quarterly', 'semi_annual', 'annual', 'custom'
                         )),
  billing_cycle_days   INT,      -- billing_cycle = 'custom' の場合のみ使用

  -- 日付
  start_date           DATE,
  next_billing_date    DATE NOT NULL,
  end_date             DATE,

  -- その他
  auto_renew           BOOLEAN NOT NULL DEFAULT TRUE,
  notes                TEXT,

  -- メタデータ
  created_by           UUID REFERENCES public.profiles(id),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- インデックス
CREATE INDEX idx_subscriptions_group_id ON public.subscriptions(group_id);
CREATE INDEX idx_subscriptions_next_billing_date ON public.subscriptions(next_billing_date);
CREATE INDEX idx_subscriptions_status ON public.subscriptions(status);
```

| カラム | 型 | 必須 | 説明 |
|--------|-----|------|------|
| id | UUID | ✅ | サブスクID（主キー） |
| group_id | UUID | ✅ | 所属グループID |
| name | TEXT | ✅ | サービス名 |
| description | TEXT | ❌ | サービス説明 |
| category_id | UUID | ❌ | カテゴリーID |
| status | TEXT | ✅ | `active` / `trial` / `inactive` / `cancelled` |
| service_url | TEXT | ❌ | サービスのURL |
| contractor_user_id | UUID | ❌ | 契約者ユーザーID |
| payment_method_note | TEXT | ❌ | 支払い方法メモ（カード名称など） |
| is_important | BOOLEAN | ✅ | 重要フラグ（相続・解約優先度） |
| amount | DECIMAL | ✅ | 請求金額 |
| currency | TEXT | ✅ | 通貨コード（ISO 4217） |
| billing_cycle | TEXT | ✅ | 請求サイクル |
| billing_cycle_days | INT | ❌ | カスタムサイクルの日数 |
| start_date | DATE | ❌ | 契約開始日 |
| next_billing_date | DATE | ✅ | 次回請求日 |
| end_date | DATE | ❌ | 契約終了日 |
| auto_renew | BOOLEAN | ✅ | 自動更新フラグ |
| notes | TEXT | ❌ | 自由メモ |
| created_by | UUID | ❌ | 登録者 |
| created_at | TIMESTAMPTZ | ✅ | 作成日時 |
| updated_at | TIMESTAMPTZ | ✅ | 更新日時 |

### 2.6 notification_settings（通知設定）

```sql
CREATE TABLE public.notification_settings (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id  UUID NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
  user_id          UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  notify_days_before INT[] NOT NULL DEFAULT ARRAY[7, 3, 1],
  is_enabled       BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (subscription_id, user_id)
);
```

| カラム | 型 | 説明 |
|--------|-----|------|
| id | UUID | 通知設定ID（主キー） |
| subscription_id | UUID | 対象サブスクID |
| user_id | UUID | 通知対象ユーザーID |
| notify_days_before | INT[] | 何日前に通知するか（例: [7, 3, 1]） |
| is_enabled | BOOLEAN | 通知有効フラグ |

### 2.7 device_tokens（デバイストークン）

```sql
CREATE TABLE public.device_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token      TEXT NOT NULL UNIQUE,
  platform   TEXT NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_device_tokens_user_id ON public.device_tokens(user_id);
```

| カラム | 型 | 説明 |
|--------|-----|------|
| id | UUID | デバイストークンID（主キー） |
| user_id | UUID | ユーザーID |
| token | TEXT | APNs デバイストークン（ユニーク） |
| platform | TEXT | プラットフォーム（現在は "ios" のみ） |
| created_at | TIMESTAMPTZ | 登録日時 |

### 2.8 exchange_rates（為替レートキャッシュ）

```sql
CREATE TABLE public.exchange_rates (
  base_currency   TEXT NOT NULL,
  target_currency TEXT NOT NULL,
  rate            DECIMAL(15, 6) NOT NULL,
  fetched_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (base_currency, target_currency)
);
```

| カラム | 型 | 説明 |
|--------|-----|------|
| base_currency | TEXT | 基軸通貨コード（例: "JPY"） |
| target_currency | TEXT | 変換先通貨コード（例: "USD"） |
| rate | DECIMAL | レート（base → target） |
| fetched_at | TIMESTAMPTZ | 取得日時 |

---

## 3. 通貨コード一覧（サポート対象）

| コード | 通貨名 |
|--------|--------|
| JPY | 日本円 |
| USD | 米ドル |
| EUR | ユーロ |
| GBP | 英ポンド |
| AUD | オーストラリアドル |
| CAD | カナダドル |
| CHF | スイスフラン |
| CNY | 中国元 |
| KRW | 韓国ウォン |
| SGD | シンガポールドル |

---

## 4. iOS ローカルモデル（Core Data）

オフラインキャッシュとして、Supabaseのデータ構造に対応するCore Dataモデルを定義する。

```
CDSubscription
  ├── id: UUID
  ├── name: String
  ├── amount: Double
  ├── currency: String
  ├── nextBillingDate: Date
  ├── status: String
  ├── isImportant: Bool
  ├── groupID: UUID
  ├── contractorUserID: UUID?
  ├── paymentMethodNote: String?
  ├── updatedAt: Date
  └── syncedAt: Date  ← ローカルキャッシュの最終同期日時

CDGroup
  ├── id: UUID
  ├── name: String
  ├── ownerID: UUID
  └── updatedAt: Date

CDProfile
  ├── id: UUID
  ├── displayName: String
  ├── baseCurrency: String
  └── avatarURL: String?
```

---

## 5. データ保持ポリシー

| データ種別 | 保持期間 | 備考 |
|-----------|---------|------|
| 有効なサブスク | 無期限 | ユーザーが削除するまで保持 |
| 解約済みサブスク | ユーザーが削除するまで | 履歴として保持 |
| 為替レートキャッシュ | 最新30件 | 古いレートは上書き |
| デバイストークン | アンインストール時に削除 | アプリ起動時に更新 |
| プッシュ通知履歴 | 保存しない | 送信のみ |
