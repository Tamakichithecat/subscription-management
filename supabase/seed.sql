-- ============================================================
-- SubTrack Family - 初期データ（シード）
-- 実行場所: Supabase Dashboard > SQL Editor
-- 実行順序: 全マイグレーション適用後に実行する
-- ============================================================


-- ============================================================
-- デフォルトカテゴリーの挿入
-- ============================================================
INSERT INTO public.categories (name, icon, color, is_default) VALUES
    ('エンタメ',           'tv.fill',             '#E74C3C', TRUE),
    ('音楽',               'music.note',           '#9B59B6', TRUE),
    ('クラウド',           'icloud.fill',          '#3498DB', TRUE),
    ('ビジネス',           'briefcase.fill',       '#2ECC71', TRUE),
    ('ニュース',           'newspaper.fill',       '#F39C12', TRUE),
    ('ゲーム',             'gamecontroller.fill',  '#1ABC9C', TRUE),
    ('学習',               'book.fill',            '#D35400', TRUE),
    ('ヘルス',             'heart.fill',           '#E91E63', TRUE),
    ('セキュリティ',       'lock.shield.fill',     '#607D8B', TRUE),
    ('その他',             'tag.fill',             '#95A5A6', TRUE)
ON CONFLICT DO NOTHING;
