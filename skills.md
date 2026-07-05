# Skills & Patterns — SubTrack Family

> このプロジェクトで発見した実装パターン・ハマりポイント・解決策の集積です。
> 新しいバグを踏んだとき・解決したときはこのファイルを更新してください。

---

## 1. Supabase RLS × PostgREST の落とし穴

### 問題: `.insert().select()` が "violates row-level security policy" になる

**現象**: グループ作成時に `groups` テーブルへのINSERTが常にRLSエラーになる。

**根本原因**:
PostgRESTは `.insert(...).select()` を **CTE（Common Table Expression）の1リクエスト**に変換する。
CTEの内部では `INSERT` とその後の `SELECT` が同一トランザクション内で評価されるが、
`groups` テーブルのINSERTには `AFTER INSERT` トリガー `handle_new_group` が設定されており、
これが `group_members` に行を追加する。

問題は、CTEのSELECT評価が**トリガー完走前**に行われるため、
SELECTのRLSポリシー `id IN (SELECT get_my_group_ids())` が空を返し、エラーになること。

```
CTE評価順序:
  1. INSERT INTO groups (CTE内)
  2. SELECT FROM groups ← ここでRLS評価（この時点でトリガーまだ未完了）
  3. AFTER INSERT トリガー handle_new_group 実行 ← group_membersに追加
```

**解決策**: 2つの独立したリクエストに分割する。

```swift
// GroupRepository.swift
func createGroup(name: String, ownerID: UUID) async throws -> SubscriptionGroup {
    // Step 1: INSERTのみ（.select()なし）→ トリガーが完走してからレスポンス返る
    try await client
        .from("groups")
        .insert(Insert(name: name, owner_id: ownerID))
        .execute()

    // Step 2: 別リクエストでSELECT → この時点でgroup_membersに行あり → RLS通過
    let dtos: [GroupDTO] = try await client
        .from("groups")
        .select()
        .eq("owner_id", value: ownerID)
        .order("created_at", ascending: false)
        .limit(1)
        .execute()
        .value

    guard let dto = dtos.first else { throw AppError.notFound }
    return dto.toDomain()
}
```

**影響範囲**: グループ作成のみ。サブスク作成（`subscriptions`テーブル）には同様のトリガーがないため`.insert().select()`で問題なし。

---

## 2. RLS ヘルパー関数（SECURITY DEFINER）

RLSポリシー内でRLSが有効なテーブルを参照すると**無限再帰**が発生する。
これを防ぐため、以下の3つのSECURITY DEFINER関数を定義済み。

```sql
-- ログインユーザーが所属するgroup_idの集合を返す
public.get_my_group_ids() → SETOF uuid

-- ユーザーが指定グループのオーナーかどうか
public.is_group_owner(p_group_id uuid) → boolean

-- ユーザーが指定グループのowner or memberかどうか
public.is_group_active_member(p_group_id uuid) → boolean
```

**使用例**:
```sql
-- RLSポリシー内では関数を使う（直接JOINしない）
USING (group_id IN (SELECT public.get_my_group_ids()))
```

**注意**: これらの関数は `search_path = public` を明示設定済み（セキュリティ要件）。

---

## 3. RLS ポリシーの命名規則

```
"テーブル名: 説明"
例: "groups: 認証済みユーザーは作成可能"
    "subscriptions: owner・memberのみ追加可能"
```

**RLS有効テーブル一覧**: profiles, groups, group_members, categories, subscriptions, notification_settings, device_tokens, exchange_rates

---

## 4. Swift 6 Strict Concurrency のルール

### @MainActor の使い方

```swift
// ViewModel・AppEnvironmentは必ず@MainActorを付ける
@Observable
@MainActor
final class DashboardViewModel { ... }
```

### async/await の呼び出し

```swift
// Viewのbodyからasyncを呼ぶ場合は.taskか Task{ }を使う
.task { await viewModel?.load() }

Button { Task { await save() } } label: { Text("保存") }
```

### Sendableエラー対策

```swift
// weak selfのキャプチャは [weak self] でSendable違反を回避
await channel.onPostgresChange(...) { [weak self] _ in
    guard let self else { return }
    ...
}
```

---

## 5. SubscriptionFormView のスクロール問題

**問題**: フォーム最下部のメモフィールドまでスクロールできない（キーボードが邪魔）。

**解決策**:
```swift
Form { ... }
    .scrollDismissesKeyboard(.interactively)  ← これを追加
```

---

## 6. groupID の誤用（よくあるバグ）

**問題**: グループスコープの操作に `currentUser?.id`（ユーザーID）を使ってしまう。

```swift
// ❌ バグ: ユーザーIDをグループIDとして渡している
guard let groupID = appEnv.currentUser?.id else { return }
subscriptions = try await useCase.fetchAll(groupID: groupID)

// ✅ 正しい: グループIDを使う
guard let groupID = appEnv.selectedGroup?.id else { return }
subscriptions = try await useCase.fetchAll(groupID: groupID)
```

**発生箇所（修正済み）**:
- `SubscriptionFormView.swift` の `save()` 関数 → 修正済み
- `ReportsView.swift` の `.task` 内 → 修正済み

---

## 7. XcodeGen の使い方

```bash
# インストール（初回）
brew install xcodegen

# プロジェクト再生成（project.yml変更後に必ず実行）
cd subscription-management
xcodegen generate
```

`project.yml` を変更した場合、`.xcodeproj` を再生成しないと変更が反映されない。
`.xcodeproj` は `.gitignore` に含まれているため、チームメンバーも各自で実行が必要。

---

## 8. Supabase Realtime の購読パターン

```swift
// AppEnvironment.swift の実装例
let channel = supabase.realtimeV2.channel("subscriptions:\(groupID)")
await channel.onPostgresChange(
    AnyAction.self,
    schema: "public",
    table: "subscriptions",
    filter: "group_id=eq.\(groupID)"
) { [weak self] _ in
    NotificationCenter.default.post(name: .subscriptionsDidChange, object: groupID)
}
await channel.subscribe()
```

購読解除はグループ切り替え・ログアウト時に行う:
```swift
await realtimeChannel?.unsubscribe()
realtimeChannel = nil
```

Viewでの受信:
```swift
.onReceive(NotificationCenter.default.publisher(for: .subscriptionsDidChange)) { _ in
    Task { await viewModel?.load() }
}
```

---

## 9. 為替レート取得

- **API**: `https://api.frankfurter.app` (APIキー不要・無料)
- **実装**: `ExchangeRateRepository.swift`
- **キャッシュ**: `exchange_rates` テーブル（Supabase）に UPSERT
- **取得タイミング**: アプリ起動時・24時間以上古い場合

---

## 10. XCUITest パターン

### 存在確認と待機

```swift
// 最大5秒待機して存在確認
XCTAssertTrue(element.waitForExistence(timeout: 5), "エラーメッセージ")

// 条件が変わるまで待機
let expectation = XCTNSPredicateExpectation(
    predicate: NSPredicate(format: "exists == false"),
    object: element
)
XCTWaiter().wait(for: [expectation], timeout: 10)
```

### テスト前提条件が満たせない場合

```swift
// 複数アカウントが必要など、自動化不可のケースはXCTSkipで明示
throw XCTSkip("GRP-3-1 SKIP: 招待コードを別アカウントから取得する手動準備が必要です")
```

### 未実装機能のテスト

```swift
throw XCTSkip("SUB-4 SKIP: カテゴリピッカーは現バージョン未実装です（既知の未実装機能）")
```

---

## 11. Supabase クライアント初期化

```swift
// SupabaseClientProvider.swift
// 環境変数または Info.plist から URL・Key を取得
let url = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
```

UITest時はスキームの環境変数が `launchEnvironment` 経由でアプリに渡される。

---

## 12. Supabase SDK のバージョン

```yaml
# project.yml
packages:
  Supabase:
    url: https://github.com/supabase/supabase-swift
    from: "2.0.0"
```

`supabase-swift` v2.x は `realtimeV2` を使用（v1の `realtime` とAPIが異なる）。
