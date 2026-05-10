/* ============================================================
   SubTrack Family - Diagnostic C
   目的: auth.uid() が NULL になっているか確認するための一時ポリシー

   【手順】
   1. このSQLをSupabase SQL Editorで実行
   2. アプリでグループ作成を試みる
      → 成功した場合: auth.uid() が NULL になっているのが原因（JWT未送信）
      → 失敗した場合: 別の箇所にエラー源がある
   3. 診断後は必ず 00009_restore_groups_policy.sql を実行して元に戻すこと
   ============================================================ */

DROP POLICY IF EXISTS "groups: 認証済みユーザーは作成可能" ON public.groups;

CREATE POLICY "groups: 認証済みユーザーは作成可能"
    ON public.groups FOR INSERT
    WITH CHECK (true);
