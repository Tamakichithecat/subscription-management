-- ============================================================
-- SubTrack Family - INSERT ポリシーの TO authenticated 問題を修正
-- 実行場所: Supabase Dashboard > SQL Editor
-- 実行順序: 00006_reset_all_rls.sql の後
--
-- 問題:
--   groups / group_members の INSERT ポリシーに「TO authenticated」
--   が指定されているため、Supabase Swift SDK の一部構成で
--   JWT が送信されても anon ロールとして扱われ INSERT が拒否される。
--
-- 修正:
--   TO authenticated を削除し、代わりに auth.uid() IS NOT NULL を
--   WITH CHECK 条件に追加することで、ロール名に依存しない
--   堅牢なポリシーに変更する。
-- ============================================================


-- ============================================================
-- Step 1: 問題のある INSERT ポリシーを個別に削除
-- ============================================================

DROP POLICY IF EXISTS "groups: 認証済みユーザーは作成可能"     ON public.groups;
DROP POLICY IF EXISTS "group_members: 自分自身のみ追加可能"    ON public.group_members;

-- 念のため旧マイグレーション（00004）由来のポリシーも削除
DROP POLICY IF EXISTS "groups: 認証済みユーザーは作成可能"     ON public.groups;
DROP POLICY IF EXISTS "group_members: オーナーのみ追加可能"    ON public.group_members;

-- categories / exchange_rates の TO authenticated も同様に修正
DROP POLICY IF EXISTS "categories: 全員閲覧可能"               ON public.categories;
DROP POLICY IF EXISTS "exchange_rates: 全員閲覧可能"           ON public.exchange_rates;


-- ============================================================
-- Step 2: ポリシーを再作成（TO authenticated なし）
-- ============================================================

-- ---- groups INSERT ------------------------------------------
-- auth.uid() IS NOT NULL でログイン済みであることを確認する。
-- TO authenticated を使わないことで、anon キー + JWT の構成でも動作する。
CREATE POLICY "groups: 認証済みユーザーは作成可能"
    ON public.groups FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND owner_id = auth.uid()
    );


-- ---- group_members INSERT -----------------------------------
-- 自分自身のレコードのみ挿入可能。
-- グループ作成時のオーナー行は handle_new_group トリガー（SECURITY DEFINER）が挿入するため、
-- このポリシーは招待コードによるグループ参加時に使用される。
CREATE POLICY "group_members: 自分自身のみ追加可能"
    ON public.group_members FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND user_id = auth.uid()
    );


-- ---- categories SELECT --------------------------------------
CREATE POLICY "categories: 全員閲覧可能"
    ON public.categories FOR SELECT
    USING (TRUE);


-- ---- exchange_rates SELECT ----------------------------------
CREATE POLICY "exchange_rates: 全員閲覧可能"
    ON public.exchange_rates FOR SELECT
    USING (TRUE);


-- ============================================================
-- 確認クエリ（実行後に貼り付けて結果を確認してください）
-- ============================================================
-- SELECT tablename, policyname, cmd, roles
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename IN ('groups', 'group_members')
-- ORDER BY tablename, cmd;
