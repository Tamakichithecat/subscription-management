-- ============================================================
-- SubTrack Family - 全 RLS ポリシーをリセットして再作成
-- 実行場所: Supabase Dashboard > SQL Editor
-- 実行順序: 00005_fix_rls_recursion.sql の後
--
-- 目的: 既存ポリシーの状態に関わらず、全テーブルの RLS を
--       クリーンな状態から正確に再構築する
-- ============================================================


-- ============================================================
-- Step 1: 全テーブルの全ポリシーを削除（IF EXISTS で安全に実行）
-- ============================================================

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT policyname, tablename
        FROM pg_policies
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I',
                       r.policyname, r.tablename);
    END LOOP;
END $$;


-- ============================================================
-- Step 2: SECURITY DEFINER ヘルパー関数を再作成（冪等）
-- ============================================================

-- 現在ユーザーが所属する全グループ ID を返す（RLS バイパス）
CREATE OR REPLACE FUNCTION public.get_my_group_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT group_id FROM public.group_members WHERE user_id = auth.uid();
$$;

-- 現在ユーザーが指定グループのオーナーか判定
CREATE OR REPLACE FUNCTION public.is_group_owner(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.group_members
        WHERE group_id = p_group_id
          AND user_id  = auth.uid()
          AND role     = 'owner'
    );
$$;

-- 現在ユーザーが指定グループの有効メンバー（owner/member）か判定
CREATE OR REPLACE FUNCTION public.is_group_active_member(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.group_members
        WHERE group_id = p_group_id
          AND user_id  = auth.uid()
          AND role     IN ('owner', 'member')
    );
$$;


-- ============================================================
-- Step 3: 全テーブルのポリシーを再作成
-- ============================================================

-- ---- profiles -----------------------------------------------

CREATE POLICY "profiles: 自分自身のみ閲覧"
    ON public.profiles FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "profiles: 同一グループメンバーは閲覧可能"
    ON public.profiles FOR SELECT
    USING (
        id IN (
            SELECT gm.user_id FROM public.group_members gm
            WHERE gm.group_id IN (SELECT public.get_my_group_ids())
        )
    );

CREATE POLICY "profiles: 自分自身のみ更新"
    ON public.profiles FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());


-- ---- groups -------------------------------------------------

-- 所属グループのみ閲覧
CREATE POLICY "groups: 所属グループのみ閲覧"
    ON public.groups FOR SELECT
    USING (id IN (SELECT public.get_my_group_ids()));

-- 認証済みユーザーはグループを作成可能
CREATE POLICY "groups: 認証済みユーザーは作成可能"
    ON public.groups FOR INSERT
    TO authenticated
    WITH CHECK (owner_id = auth.uid());

-- オーナーのみ更新可能
CREATE POLICY "groups: オーナーのみ更新可能"
    ON public.groups FOR UPDATE
    USING (public.is_group_owner(id))
    WITH CHECK (public.is_group_owner(id));

-- オーナーのみ削除可能
CREATE POLICY "groups: オーナーのみ削除可能"
    ON public.groups FOR DELETE
    USING (public.is_group_owner(id));


-- ---- group_members ------------------------------------------

-- 同一グループのメンバー一覧を閲覧可能
CREATE POLICY "group_members: 同一グループ内は閲覧可能"
    ON public.group_members FOR SELECT
    USING (group_id IN (SELECT public.get_my_group_ids()));

-- 自分自身の行のみ挿入可能
-- （グループ作成時のオーナー行は handle_new_group トリガーが挿入）
CREATE POLICY "group_members: 自分自身のみ追加可能"
    ON public.group_members FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- オーナーのみロール変更可能
CREATE POLICY "group_members: オーナーのみ更新可能"
    ON public.group_members FOR UPDATE
    USING (public.is_group_owner(group_id));

-- オーナーはメンバー削除可能・本人は脱退可能
CREATE POLICY "group_members: オーナーまたは本人のみ削除可能"
    ON public.group_members FOR DELETE
    USING (
        user_id = auth.uid()
        OR public.is_group_owner(group_id)
    );


-- ---- categories ---------------------------------------------

CREATE POLICY "categories: 全員閲覧可能"
    ON public.categories FOR SELECT
    TO authenticated
    USING (TRUE);


-- ---- subscriptions ------------------------------------------

CREATE POLICY "subscriptions: 所属グループのみ閲覧"
    ON public.subscriptions FOR SELECT
    USING (group_id IN (SELECT public.get_my_group_ids()));

CREATE POLICY "subscriptions: owner・memberのみ追加可能"
    ON public.subscriptions FOR INSERT
    WITH CHECK (public.is_group_active_member(group_id));

CREATE POLICY "subscriptions: owner・memberのみ更新可能"
    ON public.subscriptions FOR UPDATE
    USING (public.is_group_active_member(group_id));

CREATE POLICY "subscriptions: owner・memberのみ削除可能"
    ON public.subscriptions FOR DELETE
    USING (public.is_group_active_member(group_id));


-- ---- notification_settings ----------------------------------

CREATE POLICY "notification_settings: 自分のみ操作可能"
    ON public.notification_settings FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());


-- ---- device_tokens ------------------------------------------

CREATE POLICY "device_tokens: 自分のみ操作可能"
    ON public.device_tokens FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());


-- ---- exchange_rates -----------------------------------------

CREATE POLICY "exchange_rates: 全員閲覧可能"
    ON public.exchange_rates FOR SELECT
    TO authenticated
    USING (TRUE);


-- ============================================================
-- 確認クエリ: 実行後に以下で全ポリシーの存在を確認できます
-- SELECT tablename, policyname, cmd FROM pg_policies
-- WHERE schemaname = 'public' ORDER BY tablename, cmd;
-- ============================================================
