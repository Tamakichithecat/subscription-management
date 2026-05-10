/* ============================================================
   SubTrack Family - 完全診断クエリ
   目的: 現在の Supabase に存在するポリシーを全て確認する
   実行場所: Supabase Dashboard > SQL Editor
   ============================================================ */

/* 1. 全テーブルの全ポリシーを一覧表示（最重要） */
SELECT
    tablename,
    policyname,
    cmd,
    permissive,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, cmd, policyname;

/* ============================================================
   ↑ このクエリの結果を全部コピーして貼り付けてください
   ============================================================ */
