-- ============================================================
-- SubTrack Family - インデックス定義
-- 実行場所: Supabase Dashboard > SQL Editor
-- 実行順序: 00001_create_tables.sql の後に実行する
-- ============================================================

-- subscriptions
CREATE INDEX idx_subscriptions_group_id
    ON public.subscriptions(group_id);

CREATE INDEX idx_subscriptions_next_billing_date
    ON public.subscriptions(next_billing_date);

CREATE INDEX idx_subscriptions_status
    ON public.subscriptions(status);

CREATE INDEX idx_subscriptions_contractor
    ON public.subscriptions(contractor_user_id)
    WHERE contractor_user_id IS NOT NULL;

CREATE INDEX idx_subscriptions_is_important
    ON public.subscriptions(is_important)
    WHERE is_important = TRUE;

-- group_members
CREATE INDEX idx_group_members_user_id
    ON public.group_members(user_id);

-- notification_settings
CREATE INDEX idx_notification_settings_subscription
    ON public.notification_settings(subscription_id);

-- device_tokens
CREATE INDEX idx_device_tokens_user_id
    ON public.device_tokens(user_id);
