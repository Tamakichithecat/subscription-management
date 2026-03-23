-- ============================================================
-- SubTrack Family - Row Level Security (RLS) ポリシー
-- 実行場所: Supabase Dashboard > SQL Editor
-- 実行順序: 00003_create_triggers.sql の後に実行する
-- ============================================================


-- ============================================================
-- RLS 有効化
-- ============================================================
ALTER TABLE public.profiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exchange_rates        ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- profiles ポリシー
-- ============================================================

-- 自分のプロフィールのみ閲覧・更新可能
CREATE POLICY "profiles: 自分自身のみ閲覧"
    ON public.profiles FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "profiles: 自分自身のみ更新"
    ON public.profiles FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- グループメンバーは同じグループ内の他メンバーのプロフィールも閲覧可能
CREATE POLICY "profiles: 同一グループメンバーは閲覧可能"
    ON public.profiles FOR SELECT
    USING (
        id IN (
            SELECT gm2.user_id
            FROM public.group_members gm1
            JOIN public.group_members gm2 ON gm1.group_id = gm2.group_id
            WHERE gm1.user_id = auth.uid()
        )
    );


-- ============================================================
-- groups ポリシー
-- ============================================================

-- 所属グループのみ閲覧可能
CREATE POLICY "groups: 所属グループのみ閲覧"
    ON public.groups FOR SELECT
    USING (
        id IN (
            SELECT group_id FROM public.group_members
            WHERE user_id = auth.uid()
        )
    );

-- ログインユーザーはグループを作成可能
CREATE POLICY "groups: 認証済みユーザーは作成可能"
    ON public.groups FOR INSERT
    WITH CHECK (owner_id = auth.uid());

-- オーナーのみグループ情報を更新可能
CREATE POLICY "groups: オーナーのみ更新可能"
    ON public.groups FOR UPDATE
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

-- オーナーのみグループを削除可能
CREATE POLICY "groups: オーナーのみ削除可能"
    ON public.groups FOR DELETE
    USING (owner_id = auth.uid());


-- ============================================================
-- group_members ポリシー
-- ============================================================

-- 同一グループのメンバー一覧を閲覧可能
CREATE POLICY "group_members: 同一グループ内は閲覧可能"
    ON public.group_members FOR SELECT
    USING (
        group_id IN (
            SELECT group_id FROM public.group_members
            WHERE user_id = auth.uid()
        )
    );

-- オーナーのみメンバーを追加可能（招待コードによる参加はEdge Functionで処理）
CREATE POLICY "group_members: オーナーのみ追加可能"
    ON public.group_members FOR INSERT
    WITH CHECK (
        group_id IN (
            SELECT group_id FROM public.group_members
            WHERE user_id = auth.uid() AND role = 'owner'
        )
        OR user_id = auth.uid()  -- 自分自身の参加（招待コード経由）
    );

-- オーナーのみメンバーロールを変更可能
CREATE POLICY "group_members: オーナーのみ更新可能"
    ON public.group_members FOR UPDATE
    USING (
        group_id IN (
            SELECT group_id FROM public.group_members
            WHERE user_id = auth.uid() AND role = 'owner'
        )
    );

-- オーナーはメンバー削除可能・本人は脱退可能
CREATE POLICY "group_members: オーナーまたは本人のみ削除可能"
    ON public.group_members FOR DELETE
    USING (
        user_id = auth.uid()
        OR group_id IN (
            SELECT group_id FROM public.group_members
            WHERE user_id = auth.uid() AND role = 'owner'
        )
    );


-- ============================================================
-- categories ポリシー
-- ============================================================

-- 全員が閲覧可能（デフォルトカテゴリーは共有リソース）
CREATE POLICY "categories: 全員閲覧可能"
    ON public.categories FOR SELECT
    TO authenticated
    USING (TRUE);


-- ============================================================
-- subscriptions ポリシー
-- ============================================================

-- 所属グループのサブスクのみ閲覧可能
CREATE POLICY "subscriptions: 所属グループのみ閲覧"
    ON public.subscriptions FOR SELECT
    USING (
        group_id IN (
            SELECT group_id FROM public.group_members
            WHERE user_id = auth.uid()
        )
    );

-- owner/member ロールのみ追加可能
CREATE POLICY "subscriptions: owner・memberのみ追加可能"
    ON public.subscriptions FOR INSERT
    WITH CHECK (
        group_id IN (
            SELECT group_id FROM public.group_members
            WHERE user_id = auth.uid()
              AND role IN ('owner', 'member')
        )
    );

-- owner/member ロールのみ更新可能
CREATE POLICY "subscriptions: owner・memberのみ更新可能"
    ON public.subscriptions FOR UPDATE
    USING (
        group_id IN (
            SELECT group_id FROM public.group_members
            WHERE user_id = auth.uid()
              AND role IN ('owner', 'member')
        )
    );

-- owner/member ロールのみ削除可能
CREATE POLICY "subscriptions: owner・memberのみ削除可能"
    ON public.subscriptions FOR DELETE
    USING (
        group_id IN (
            SELECT group_id FROM public.group_members
            WHERE user_id = auth.uid()
              AND role IN ('owner', 'member')
        )
    );


-- ============================================================
-- notification_settings ポリシー
-- ============================================================

-- 自分の通知設定のみ操作可能
CREATE POLICY "notification_settings: 自分のみ操作可能"
    ON public.notification_settings FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());


-- ============================================================
-- device_tokens ポリシー
-- ============================================================

-- 自分のデバイストークンのみ操作可能
CREATE POLICY "device_tokens: 自分のみ操作可能"
    ON public.device_tokens FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());


-- ============================================================
-- exchange_rates ポリシー
-- ============================================================

-- 全員が閲覧可能（公開レートデータ）
CREATE POLICY "exchange_rates: 全員閲覧可能"
    ON public.exchange_rates FOR SELECT
    TO authenticated
    USING (TRUE);
