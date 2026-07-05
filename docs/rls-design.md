# RLS（Row Level Security）設計書

**最終更新**: 2026-07-05
**対応マイグレーション**: 00008_definitive_rls.sql, 00012_restore_groups_insert_policy.sql

---

## 1. 設計方針

- 全テーブルにRLSを有効化し、デフォルト拒否（deny-by-default）
- **RLS内でRLS有効テーブルへの直接JOIN禁止**（無限再帰が発生するため）
- 代わりに `SECURITY DEFINER` ヘルパー関数を経由してポリシーを記述
- ポリシーに `TO authenticated` を付与しない（テスト・診断時の混乱を防ぐため）

---

## 2. SECURITY DEFINER ヘルパー関数

```sql
-- ログインユーザーが所属するすべてのgroup_idを返す
CREATE OR REPLACE FUNCTION public.get_my_group_ids()
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT group_id FROM public.group_members WHERE user_id = auth.uid();
$$;

-- ユーザーが指定グループのオーナーであればtrue
CREATE OR REPLACE FUNCTION public.is_group_owner(p_group_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = auth.uid() AND role = 'owner'
  );
$$;

-- ユーザーが指定グループのowner or memberであればtrue（viewerは除く）
CREATE OR REPLACE FUNCTION public.is_group_active_member(p_group_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = auth.uid() AND role IN ('owner','member')
  );
$$;
```

---

## 3. テーブル別 RLS ポリシー一覧

### profiles

| 操作 | ポリシー名 | 条件 |
|------|-----------|------|
| SELECT | 自分自身のみ閲覧 | `id = auth.uid()` |
| SELECT | 同一グループメンバーは閲覧可能 | `id IN (同グループのuser_id)` |
| UPDATE | 自分自身のみ更新 | `id = auth.uid()` |

### groups

| 操作 | ポリシー名 | 条件 |
|------|-----------|------|
| SELECT | 所属グループのみ閲覧 | `id IN (get_my_group_ids())` |
| INSERT | 認証済みユーザーは作成可能 | `auth.uid() IS NOT NULL AND owner_id = auth.uid()` |
| UPDATE | オーナーのみ更新可能 | `is_group_owner(id)` |
| DELETE | オーナーのみ削除可能 | `is_group_owner(id)` |

### group_members

| 操作 | ポリシー名 | 条件 |
|------|-----------|------|
| SELECT | 同一グループ内は閲覧可能 | `group_id IN (get_my_group_ids())` |
| INSERT | 自分自身のみ追加可能 | `auth.uid() IS NOT NULL AND user_id = auth.uid()` |
| UPDATE | オーナーのみ更新可能 | `is_group_owner(group_id)` |
| DELETE | オーナーまたは本人のみ削除可能 | `user_id = auth.uid() OR is_group_owner(group_id)` |

### categories

| 操作 | ポリシー名 | 条件 |
|------|-----------|------|
| SELECT | 全員閲覧可能 | `TRUE` |

### subscriptions

| 操作 | ポリシー名 | 条件 |
|------|-----------|------|
| SELECT | 所属グループのみ閲覧 | `group_id IN (get_my_group_ids())` |
| INSERT | owner・memberのみ追加可能 | `is_group_active_member(group_id)` |
| UPDATE | owner・memberのみ更新可能 | `is_group_active_member(group_id)` |
| DELETE | owner・memberのみ削除可能 | `is_group_active_member(group_id)` |

### notification_settings / device_tokens

| 操作 | ポリシー名 | 条件 |
|------|-----------|------|
| ALL | 自分のみ操作可能 | `user_id = auth.uid()` |

### exchange_rates

| 操作 | ポリシー名 | 条件 |
|------|-----------|------|
| SELECT | 全員閲覧可能 | `TRUE` |

---

## 4. 既知のバグと解決策

### バグ: グループ作成時 "violates row-level security policy for table 'groups'"

**診断期間**: 2026年（マイグレーション00004〜00012で対応）

**根本原因（確定）**: PostgRESTの `.insert().select()` は内部でCTEに変換される。

```sql
-- PostgRESTが内部生成するSQL（概念）
WITH inserted AS (
  INSERT INTO groups (name, owner_id) VALUES (...) RETURNING *
)
SELECT * FROM inserted;  -- ← ここでRLS評価
                         -- AFTER INSERTトリガーはまだ未完了
                         -- group_membersに行がないためget_my_group_ids()が空
                         -- SELECT RLSが拒否 → エラー
```

**解決策**: iOS側でINSERTとSELECTを2つの独立したリクエストに分割。
実装ファイル: `SubTrackFamily/Data/Repositories/GroupRepository.swift`

```swift
// INSERT（.execute()のみ、.value取得なし）
try await client.from("groups").insert(payload).execute()

// 別リクエストでSELECT
let dtos: [GroupDTO] = try await client
    .from("groups").select()
    .eq("owner_id", value: ownerID)
    .order("created_at", ascending: false)
    .limit(1)
    .execute().value
```

**なぜ他のテーブルで問題が出ないか**: `subscriptions` テーブルには AFTER INSERT トリガーがないため、CTEでもRLS評価タイミングに問題が生じない。

---

## 5. マイグレーション履歴

| ファイル | 目的 | 状態 |
|---------|------|------|
| 00001_create_tables.sql | テーブル定義 | 本番適用済み |
| 00002_create_indexes.sql | インデックス | 本番適用済み |
| 00003_create_triggers.sql | トリガー（handle_new_user, handle_new_group） | 本番適用済み |
| 00004_create_rls.sql | RLS初版 | 00008で上書き |
| 00005_fix_rls_recursion.sql | RLS無限再帰修正 | 00008で上書き |
| 00006_reset_all_rls.sql | RLS全リセット | 00008で上書き |
| 00007_fix_insert_policies.sql | INSERTポリシー修正 | 00008で上書き |
| 00008_definitive_rls.sql | **現行RLS定義（正規版）** | 本番適用済み |
| 00009_diagnostic_c.sql | 診断用（groups INSERT を WITH CHECK true に変更） | 診断後00012で復元 |
| 00009_restore_groups_policy.sql | 診断後復元 | 00012で上書き |
| 00010_full_diagnosis.sql | pg_policies全体確認 | 診断専用 |
| 00011_nuclear_reset.sql | 全ポリシー再生成（緊急用） | 00008と同内容 |
| 00012_restore_groups_insert_policy.sql | groups INSERTポリシーを正式版に戻す | 本番適用済み |

> **現行の正しいポリシー状態**: `00008_definitive_rls.sql` の内容に `00012` での `groups INSERT` ポリシー上書きを加えたもの。
