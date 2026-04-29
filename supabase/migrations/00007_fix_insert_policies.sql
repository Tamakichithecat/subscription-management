/* SubTrack Family - Fix INSERT policies (remove TO authenticated)
   Run in: Supabase Dashboard > SQL Editor
   Run after: 00006_reset_all_rls.sql
*/

DROP POLICY IF EXISTS "groups: 認証済みユーザーは作成可能"  ON public.groups;
DROP POLICY IF EXISTS "group_members: 自分自身のみ追加可能" ON public.group_members;
DROP POLICY IF EXISTS "group_members: オーナーのみ追加可能" ON public.group_members;
DROP POLICY IF EXISTS "categories: 全員閲覧可能"            ON public.categories;
DROP POLICY IF EXISTS "exchange_rates: 全員閲覧可能"        ON public.exchange_rates;

CREATE POLICY "groups: 認証済みユーザーは作成可能"
    ON public.groups FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL AND owner_id = auth.uid());

CREATE POLICY "group_members: 自分自身のみ追加可能"
    ON public.group_members FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());

CREATE POLICY "categories: 全員閲覧可能"
    ON public.categories FOR SELECT
    USING (TRUE);

CREATE POLICY "exchange_rates: 全員閲覧可能"
    ON public.exchange_rates FOR SELECT
    USING (TRUE);
