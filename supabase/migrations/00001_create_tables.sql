-- ============================================================
-- SubTrack Family - テーブル定義
-- 実行場所: Supabase Dashboard > SQL Editor
-- 実行順序: このファイルを最初に実行する
-- ============================================================


-- ============================================================
-- 1. profiles（ユーザープロフィール）
-- ============================================================
CREATE TABLE public.profiles (
    id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name  TEXT NOT NULL,
    avatar_url    TEXT,
    base_currency TEXT NOT NULL DEFAULT 'JPY',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.profiles IS 'ユーザープロフィール（auth.usersの拡張）';


-- ============================================================
-- 2. groups（家族グループ）
-- ============================================================
CREATE TABLE public.groups (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    owner_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    invite_code TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(6), 'hex'),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.groups IS '家族グループ';
COMMENT ON COLUMN public.groups.invite_code IS '招待コード（12桁HEX）';


-- ============================================================
-- 3. group_members（グループメンバー）
-- ============================================================
CREATE TABLE public.group_members (
    group_id  UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    user_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role      TEXT NOT NULL DEFAULT 'member'
                CHECK (role IN ('owner', 'member', 'viewer')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, user_id)
);

COMMENT ON TABLE public.group_members IS 'グループメンバーとロール';


-- ============================================================
-- 4. categories（カテゴリー）
-- ============================================================
CREATE TABLE public.categories (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT NOT NULL,
    icon       TEXT NOT NULL DEFAULT 'tag.fill',
    color      TEXT NOT NULL DEFAULT '#95A5A6',
    is_default BOOLEAN NOT NULL DEFAULT FALSE
);

COMMENT ON TABLE public.categories IS 'サブスクカテゴリー（SF Symbols アイコン名・HEXカラー）';


-- ============================================================
-- 5. subscriptions（サブスクリプション）
-- ============================================================
CREATE TABLE public.subscriptions (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id             UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,

    -- 基本情報
    name                 TEXT NOT NULL,
    description          TEXT,
    category_id          UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    status               TEXT NOT NULL DEFAULT 'active'
                           CHECK (status IN ('active', 'trial', 'inactive', 'cancelled')),
    service_url          TEXT,

    -- 契約情報（相続対応）
    contractor_user_id   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    payment_method_note  TEXT,
    is_important         BOOLEAN NOT NULL DEFAULT FALSE,

    -- 請求情報
    amount               DECIMAL(12, 2) NOT NULL CHECK (amount >= 0),
    currency             TEXT NOT NULL DEFAULT 'JPY',
    billing_cycle        TEXT NOT NULL DEFAULT 'monthly'
                           CHECK (billing_cycle IN (
                               'daily', 'weekly', 'monthly',
                               'quarterly', 'semi_annual', 'annual', 'custom'
                           )),
    billing_cycle_days   INT CHECK (billing_cycle_days > 0),

    -- 日付
    start_date           DATE,
    next_billing_date    DATE NOT NULL,
    end_date             DATE,

    -- その他
    auto_renew           BOOLEAN NOT NULL DEFAULT TRUE,
    notes                TEXT,

    -- メタデータ
    created_by           UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 整合性チェック
    CONSTRAINT billing_cycle_days_required
        CHECK (billing_cycle != 'custom' OR billing_cycle_days IS NOT NULL)
);

COMMENT ON TABLE public.subscriptions IS 'サブスクリプション管理';
COMMENT ON COLUMN public.subscriptions.payment_method_note IS '支払い方法メモ（カード番号等は保存しない）';
COMMENT ON COLUMN public.subscriptions.is_important IS '相続・解約優先度の高いサブスク';


-- ============================================================
-- 6. notification_settings（通知設定）※ v1.1で使用
-- ============================================================
CREATE TABLE public.notification_settings (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id   UUID NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
    user_id           UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    notify_days_before INT[] NOT NULL DEFAULT ARRAY[7, 3, 1],
    is_enabled        BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (subscription_id, user_id)
);

COMMENT ON TABLE public.notification_settings IS 'プッシュ通知設定（v1.1以降）';


-- ============================================================
-- 7. device_tokens（APNsデバイストークン）※ v1.1で使用
-- ============================================================
CREATE TABLE public.device_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token      TEXT NOT NULL UNIQUE,
    platform   TEXT NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.device_tokens IS 'APNsデバイストークン（v1.1以降）';


-- ============================================================
-- 8. exchange_rates（為替レートキャッシュ）
-- ============================================================
CREATE TABLE public.exchange_rates (
    base_currency   TEXT NOT NULL,
    target_currency TEXT NOT NULL,
    rate            DECIMAL(15, 6) NOT NULL CHECK (rate > 0),
    fetched_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (base_currency, target_currency)
);

COMMENT ON TABLE public.exchange_rates IS '為替レートキャッシュ（frankfurter.appから日次取得）';
