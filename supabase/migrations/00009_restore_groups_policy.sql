/* ============================================================
   SubTrack Family - Diagnostic C の後始末
   目的: 00009_diagnostic_c.sql の一時ポリシーを正しいポリシーに戻す
   実行タイミング: diagnostic C テスト完了後
   ============================================================ */

DROP POLICY IF EXISTS "groups: 認証済みユーザーは作成可能" ON public.groups;

CREATE POLICY "groups: 認証済みユーザーは作成可能"
    ON public.groups FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL AND owner_id = auth.uid());
