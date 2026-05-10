/* ============================================================
   SubTrack Family - 完全リセット（Nuclear Option）
   目的: pg_policies を使って現在存在する全ポリシーを確実に削除し
         ゼロから再構築する。00006〜00009 の残骸も全て排除。
   実行場所: Supabase Dashboard > SQL Editor
   注意: 一度実行すると全ポリシーが消えるので、このファイルを
         最後まで一括で実行すること。
   ============================================================ */


/* ============================================================
   Step 1: 現在存在する全ポリシーを動的に削除
   ============================================================ */
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT policyname, tablename
        FROM pg_policies
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            r.policyname, r.tablename
        );
    END LOOP;
END $$;


/* ============================================================
   Step 2: RLS が有効になっていることを確認（冪等）
   ============================================================ */
ALTER TABLE public.profiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exchange_rates        ENABLE ROW LEVEL SECURITY;


/* ============================================================
   Step 3: ヘルパー関数を再作成（冪等）
   ============================================================ */

CREATE OR REPLACE FUNCTION public.get_my_group_ids()
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $func$ SELECT group_id FROM public.group_members WHERE user_id = auth.uid(); $func$;

CREATE OR REPLACE FUNCTION public.is_group_owner(p_group_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $func$
    SELECT EXISTS (
        SELECT 1 FROM public.group_members
        WHERE group_id = p_group_id AND user_id = auth.uid() AND role = 'owner'
    );
$func$;

CREATE OR REPLACE FUNCTION public.is_group_active_member(p_group_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $func$
    SELECT EXISTS (
        SELECT 1 FROM public.group_members
        WHERE group_id = p_group_id AND user_id = auth.uid() AND role IN ('owner','member')
    );
$func$;


/* ============================================================
   Step 4: 全ポリシーをゼロから作成
   ============================================================ */

/* profiles */
CREATE POLICY profiles_select_self
    ON public.profiles FOR SELECT
    USING (id = auth.uid());

CREATE POLICY profiles_select_group_members
    ON public.profiles FOR SELECT
    USING (id IN (
        SELECT gm.user_id FROM public.group_members gm
        WHERE gm.group_id IN (SELECT public.get_my_group_ids())
    ));

CREATE POLICY profiles_update_self
    ON public.profiles FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

/* groups */
CREATE POLICY groups_select
    ON public.groups FOR SELECT
    USING (id IN (SELECT public.get_my_group_ids()));

CREATE POLICY groups_insert
    ON public.groups FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL AND owner_id = auth.uid());

CREATE POLICY groups_update
    ON public.groups FOR UPDATE
    USING (public.is_group_owner(id))
    WITH CHECK (public.is_group_owner(id));

CREATE POLICY groups_delete
    ON public.groups FOR DELETE
    USING (public.is_group_owner(id));

/* group_members */
CREATE POLICY group_members_select
    ON public.group_members FOR SELECT
    USING (group_id IN (SELECT public.get_my_group_ids()));

CREATE POLICY group_members_insert
    ON public.group_members FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());

CREATE POLICY group_members_update
    ON public.group_members FOR UPDATE
    USING (public.is_group_owner(group_id));

CREATE POLICY group_members_delete
    ON public.group_members FOR DELETE
    USING (user_id = auth.uid() OR public.is_group_owner(group_id));

/* categories */
CREATE POLICY categories_select
    ON public.categories FOR SELECT
    USING (TRUE);

/* subscriptions */
CREATE POLICY subscriptions_select
    ON public.subscriptions FOR SELECT
    USING (group_id IN (SELECT public.get_my_group_ids()));

CREATE POLICY subscriptions_insert
    ON public.subscriptions FOR INSERT
    WITH CHECK (public.is_group_active_member(group_id));

CREATE POLICY subscriptions_update
    ON public.subscriptions FOR UPDATE
    USING (public.is_group_active_member(group_id));

CREATE POLICY subscriptions_delete
    ON public.subscriptions FOR DELETE
    USING (public.is_group_active_member(group_id));

/* notification_settings */
CREATE POLICY notification_settings_all
    ON public.notification_settings FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

/* device_tokens */
CREATE POLICY device_tokens_all
    ON public.device_tokens FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

/* exchange_rates */
CREATE POLICY exchange_rates_select
    ON public.exchange_rates FOR SELECT
    USING (TRUE);


/* ============================================================
   Step 5: 確認クエリ（実行後にポリシー一覧を表示）
   ============================================================ */
SELECT tablename, policyname, cmd, with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, cmd;
