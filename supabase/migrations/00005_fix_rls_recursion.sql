-- ============================================================
-- SubTrack Family - RLS 無限再帰バグ修正
-- 実行場所: Supabase Dashboard > SQL Editor
-- 実行順序: 00004_create_rls.sql の後に実行する
--
-- 問題: group_members の RLS ポリシーが自己参照し無限再帰が発生
-- 解決: SECURITY DEFINER ヘルパー関数で RLS をバイパスする
-- ============================================================


-- ============================================================
-- Step 1: 再帰を引き起こしているポリシーを全て削除
-- ============================================================

-- group_members
DROP POLICY IF EXISTS "group_members: 同一グループ内は閲覧可能"    ON public.group_members;
DROP POLICY IF EXISTS "group_members: オーナーのみ追加可能"         ON public.group_members;
DROP POLICY IF EXISTS "group_members: オーナーのみ更新可能"         ON public.group_members;
DROP POLICY IF EXISTS "group_members: オーナーまたは本人のみ削除可能" ON public.group_members;

-- groups（group_members を参照しているため同様に再帰）
DROP POLICY IF EXISTS "groups: 所属グループのみ閲覧"               ON public.groups;
DROP POLICY IF EXISTS "groups: オーナーのみ更新可能"                ON public.groups;
DROP POLICY IF EXISTS "groups: オーナーのみ削除可能"                ON public.groups;

-- profiles
DROP POLICY IF EXISTS "profiles: 同一グループメンバーは閲覧可能"   ON public.profiles;

-- subscriptions
DROP POLICY IF EXISTS "subscriptions: 所属グループのみ閲覧"         ON public.subscriptions;
DROP POLICY IF EXISTS "subscriptions: owner・memberのみ追加可能"    ON public.subscriptions;
DROP POLICY IF EXISTS "subscriptions: owner・memberのみ更新可能"    ON public.subscriptions;
DROP POLICY IF EXISTS "subscriptions: owner・memberのみ削除可能"    ON public.subscriptions;


-- ============================================================
-- Step 2: SECURITY DEFINER ヘルパー関数を作成
--   SECURITY DEFINER = 関数オーナー（postgres）として実行されるため
--   RLS をバイパスでき、再帰を回避できる
-- ============================================================

-- 現在のユーザーが所属する全グループIDを返す
CREATE OR REPLACE FUNCTION public.get_my_group_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT group_id
    FROM public.group_members
    WHERE user_id = auth.uid();
$$;

-- 現在のユーザーが特定グループのオーナーかどうかを返す
CREATE OR REPLACE FUNCTION public.is_group_owner(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.group_members
        WHERE group_id = p_group_id
          AND user_id  = auth.uid()
          AND role     = 'owner'
    );
$$;

-- 現在のユーザーが特定グループの有効メンバー（owner/member）かどうかを返す
CREATE OR REPLACE FUNCTION public.is_group_active_member(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.group_members
        WHERE group_id = p_group_id
          AND user_id  = auth.uid()
          AND role     IN ('owner', 'member')
    );
$$;


-- ============================================================
-- Step 3: ヘルパー関数を使ってポリシーを再作成
-- ============================================================

-- ---- group_members ----------------------------------------

-- 自分が所属するグループのメンバー一覧のみ閲覧可能
CREATE POLICY "group_members: 同一グループ内は閲覧可能"
    ON public.group_members FOR SELECT
    USING (group_id IN (SELECT public.get_my_group_ids()));

-- 自分自身のレコードのみ挿入可能
-- （グループ作成時のオーナー行は handle_new_group トリガーが挿入）
CREATE POLICY "group_members: 自分自身のみ追加可能"
    ON public.group_members FOR INSERT
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


-- ---- groups ------------------------------------------------

-- 所属グループのみ閲覧可能
CREATE POLICY "groups: 所属グループのみ閲覧"
    ON public.groups FOR SELECT
    USING (id IN (SELECT public.get_my_group_ids()));

-- オーナーのみグループ情報を更新可能
CREATE POLICY "groups: オーナーのみ更新可能"
    ON public.groups FOR UPDATE
    USING (public.is_group_owner(id))
    WITH CHECK (public.is_group_owner(id));

-- オーナーのみグループを削除可能
CREATE POLICY "groups: オーナーのみ削除可能"
    ON public.groups FOR DELETE
    USING (public.is_group_owner(id));


-- ---- profiles ----------------------------------------------

-- 同一グループメンバーのプロフィールも閲覧可能
CREATE POLICY "profiles: 同一グループメンバーは閲覧可能"
    ON public.profiles FOR SELECT
    USING (
        id IN (
            SELECT gm.user_id
            FROM public.group_members gm
            WHERE gm.group_id IN (SELECT public.get_my_group_ids())
        )
    );


-- ---- subscriptions -----------------------------------------

-- 所属グループのサブスクのみ閲覧可能
CREATE POLICY "subscriptions: 所属グループのみ閲覧"
    ON public.subscriptions FOR SELECT
    USING (group_id IN (SELECT public.get_my_group_ids()));

-- owner/member ロールのみ追加可能
CREATE POLICY "subscriptions: owner・memberのみ追加可能"
    ON public.subscriptions FOR INSERT
    WITH CHECK (public.is_group_active_member(group_id));

-- owner/member ロールのみ更新可能
CREATE POLICY "subscriptions: owner・memberのみ更新可能"
    ON public.subscriptions FOR UPDATE
    USING (public.is_group_active_member(group_id));

-- owner/member ロールのみ削除可能
CREATE POLICY "subscriptions: owner・memberのみ削除可能"
    ON public.subscriptions FOR DELETE
    USING (public.is_group_active_member(group_id));
