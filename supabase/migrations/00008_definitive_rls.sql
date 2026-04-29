/* ============================================================
   SubTrack Family - Definitive RLS reset
   Run in: Supabase Dashboard > SQL Editor
   Supersedes migrations 00004 to 00007.
   Safe to run multiple times (idempotent).
   ============================================================ */


/* Step 1: Drop ALL known policies across all migration versions */

DROP POLICY IF EXISTS "profiles: 自分自身のみ閲覧"             ON public.profiles;
DROP POLICY IF EXISTS "profiles: 同一グループメンバーは閲覧可能" ON public.profiles;
DROP POLICY IF EXISTS "profiles: 自分自身のみ更新"             ON public.profiles;

DROP POLICY IF EXISTS "groups: 所属グループのみ閲覧"            ON public.groups;
DROP POLICY IF EXISTS "groups: 認証済みユーザーは作成可能"      ON public.groups;
DROP POLICY IF EXISTS "groups: オーナーのみ更新可能"            ON public.groups;
DROP POLICY IF EXISTS "groups: オーナーのみ削除可能"            ON public.groups;

DROP POLICY IF EXISTS "group_members: 同一グループ内は閲覧可能"      ON public.group_members;
DROP POLICY IF EXISTS "group_members: 自分自身のみ追加可能"          ON public.group_members;
DROP POLICY IF EXISTS "group_members: オーナーのみ追加可能"          ON public.group_members;
DROP POLICY IF EXISTS "group_members: オーナーのみ更新可能"          ON public.group_members;
DROP POLICY IF EXISTS "group_members: オーナーまたは本人のみ削除可能" ON public.group_members;

DROP POLICY IF EXISTS "categories: 全員閲覧可能"                ON public.categories;

DROP POLICY IF EXISTS "subscriptions: 所属グループのみ閲覧"         ON public.subscriptions;
DROP POLICY IF EXISTS "subscriptions: owner・memberのみ追加可能"    ON public.subscriptions;
DROP POLICY IF EXISTS "subscriptions: owner・memberのみ更新可能"    ON public.subscriptions;
DROP POLICY IF EXISTS "subscriptions: owner・memberのみ削除可能"    ON public.subscriptions;

DROP POLICY IF EXISTS "notification_settings: 自分のみ操作可能" ON public.notification_settings;
DROP POLICY IF EXISTS "device_tokens: 自分のみ操作可能"         ON public.device_tokens;
DROP POLICY IF EXISTS "exchange_rates: 全員閲覧可能"            ON public.exchange_rates;


/* Step 2: Recreate helper functions (SECURITY DEFINER, bypasses RLS) */

CREATE OR REPLACE FUNCTION public.get_my_group_ids()
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT group_id FROM public.group_members WHERE user_id = auth.uid(); $$;

CREATE OR REPLACE FUNCTION public.is_group_owner(p_group_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = auth.uid() AND role = 'owner'
); $$;

CREATE OR REPLACE FUNCTION public.is_group_active_member(p_group_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = auth.uid() AND role IN ('owner','member')
); $$;


/* Step 3: Recreate all policies
   NOTE: No "TO authenticated" anywhere.
         INSERT policies use "auth.uid() IS NOT NULL" instead. */

/* profiles */
CREATE POLICY "profiles: 自分自身のみ閲覧"
    ON public.profiles FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "profiles: 同一グループメンバーは閲覧可能"
    ON public.profiles FOR SELECT
    USING (id IN (
        SELECT gm.user_id FROM public.group_members gm
        WHERE gm.group_id IN (SELECT public.get_my_group_ids())
    ));

CREATE POLICY "profiles: 自分自身のみ更新"
    ON public.profiles FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

/* groups */
CREATE POLICY "groups: 所属グループのみ閲覧"
    ON public.groups FOR SELECT
    USING (id IN (SELECT public.get_my_group_ids()));

CREATE POLICY "groups: 認証済みユーザーは作成可能"
    ON public.groups FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL AND owner_id = auth.uid());

CREATE POLICY "groups: オーナーのみ更新可能"
    ON public.groups FOR UPDATE
    USING (public.is_group_owner(id))
    WITH CHECK (public.is_group_owner(id));

CREATE POLICY "groups: オーナーのみ削除可能"
    ON public.groups FOR DELETE
    USING (public.is_group_owner(id));

/* group_members */
CREATE POLICY "group_members: 同一グループ内は閲覧可能"
    ON public.group_members FOR SELECT
    USING (group_id IN (SELECT public.get_my_group_ids()));

CREATE POLICY "group_members: 自分自身のみ追加可能"
    ON public.group_members FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());

CREATE POLICY "group_members: オーナーのみ更新可能"
    ON public.group_members FOR UPDATE
    USING (public.is_group_owner(group_id));

CREATE POLICY "group_members: オーナーまたは本人のみ削除可能"
    ON public.group_members FOR DELETE
    USING (user_id = auth.uid() OR public.is_group_owner(group_id));

/* categories */
CREATE POLICY "categories: 全員閲覧可能"
    ON public.categories FOR SELECT
    USING (TRUE);

/* subscriptions */
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

/* notification_settings */
CREATE POLICY "notification_settings: 自分のみ操作可能"
    ON public.notification_settings FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

/* device_tokens */
CREATE POLICY "device_tokens: 自分のみ操作可能"
    ON public.device_tokens FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

/* exchange_rates */
CREATE POLICY "exchange_rates: 全員閲覧可能"
    ON public.exchange_rates FOR SELECT
    USING (TRUE);
