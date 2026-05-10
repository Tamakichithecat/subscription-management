/* ============================================================
   SubTrack Family - groups INSERT ポリシーを正式版に戻す
   目的: diagnostic C で WITH CHECK (true) になっていたポリシーを
         正しい制限付きポリシーに戻す
   実行場所: Supabase Dashboard > SQL Editor
   ============================================================ */

DROP POLICY IF EXISTS "groups: 認証済みユーザーは作成可能" ON public.groups;

CREATE POLICY "groups: 認証済みユーザーは作成可能"
    ON public.groups FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL AND owner_id = auth.uid());
