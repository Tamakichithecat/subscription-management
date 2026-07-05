# Agent Guide — SubTrack Family

> AIエージェントがこのプロジェクトで作業するための運用ガイドです。
> CLAUDE.md を先に読んでいることを前提とします。

---

## 作業開始前のチェックリスト

1. `CLAUDE.md` を読む（プロジェクト全体像の把握）
2. `skills.md` を読む（実装パターン・ハマりポイントの確認）
3. `docs/known-issues.md` を読む（既知バグを再実装しないため）
4. 対象ファイルを Read ツールで確認してから編集する
5. Swift 6 Strict Concurrency に準拠する（コンパイルエラーになるため）

---

## ブランチ・コミット規約

```
ブランチ: architect（すべての開発作業はここ）
コミットメッセージ形式:
  feat(scope): 日本語で内容を記述
  fix(scope): バグ修正
  docs(scope): ドキュメント更新
  test(scope): テスト追加・修正
  refactor(scope): リファクタリング

例:
  feat(subscription): カテゴリピッカーをフォームに追加
  fix(reports): fetchAllのgroupIDをselectedGroup?.idに修正
```

---

## ファイル編集ルール

### Swiftファイル

- **新規Viewを追加するとき**: `Presentation/` の対応カテゴリ配下に配置
- **新規Entityを追加するとき**: `Domain/Entities/` に配置、DTO は `Data/Remote/DTOs/` に追加
- **新規Repositoryを追加するとき**:
  1. `Domain/Repositories/` にプロトコルを定義
  2. `Data/Repositories/` に実装クラスを作成
  3. `AppEnvironment.swift` に依存注入を追加
- **accessibilityIdentifier**: UITestが存在するため、キーUI要素には必ず付与する（`skills.md` の識別子一覧を参照）

### SQLマイグレーション

- 新規マイグレーションは `supabase/migrations/` に `000XX_description.sql` 形式で追加
- RLSポリシーを変更するときは必ず `docs/rls-design.md` を確認し、既存ポリシーとの整合性を保つ
- **絶対禁止**: RLSを無効化したままにしない

### project.yml

- 変更後は必ずユーザーに `xcodegen generate` の実行を依頼する
- ターゲット追加・削除時は `schemes:` の `build:targets:` も更新する

---

## よく使う実装パターン

### グループスコープのデータ取得

```swift
// ✅ 正しい
guard let groupID = appEnv.selectedGroup?.id else { return }
let subs = try await appEnv.subscriptionUseCase.fetchAll(groupID: groupID)

// ❌ 誤り（currentUser.id はユーザーID、グループIDではない）
guard let groupID = appEnv.currentUser?.id else { return }
```

### 非同期処理（Swift 6 準拠）

```swift
// ViewでTask化する場合
.task {
    await viewModel?.load()
}

// ボタンアクションでTask化する場合
Button {
    Task { await save() }
} label: { Text("保存") }
```

### Supabase 2ステップ INSERT（グループ作成）

```swift
// Step 1: INSERT（SELECTなし）→ AFTER INSERT トリガーが完走
try await client.from("groups").insert(payload).execute()

// Step 2: 別リクエストでSELECT → RLS通過
let dtos: [GroupDTO] = try await client
    .from("groups")
    .select()
    .eq("owner_id", value: ownerID)
    .order("created_at", ascending: false)
    .limit(1)
    .execute()
    .value
```

### @Observable の状態更新

```swift
@Observable
@MainActor
final class SomeViewModel {
    var items: [Item] = []

    func load() async {
        items = (try? await useCase.fetch()) ?? []
    }
}
```

---

## タブバー構成（MainTabView）

| タブラベル | systemImage | View |
|-----------|-------------|------|
| ホーム | house.fill | DashboardView |
| サブスク | list.bullet.rectangle | SubscriptionListView |
| 契約情報 | doc.text.magnifyingglass | ContractListView |
| ファミリー | person.2.fill | FamilyGroupView |
| 設定 | gearshape.fill | SettingsView |

> **注意**: ReportsView はタブに含まれていない（現バージョン）。SettingsViewやFamilyGroupViewからのナビゲーションも未実装。

---

## UITest の accessibilityIdentifier 一覧

| 識別子 | 場所 | 種別 |
|--------|------|------|
| `btn_signin` | WelcomeView | Button |
| `btn_signup` | WelcomeView | Button |
| `field_email` | SignInView / SignUpView | TextField |
| `field_password` | SignInView / SignUpView | SecureField |
| `btn_login` | SignInView | Button |
| `field_displayName` | SignUpView | TextField |
| `btn_register` | SignUpView | Button |
| `btn_createGroup` | GroupSelectionView | Button |
| `btn_joinGroup` | GroupSelectionView | Button |
| `field_groupName` | CreateGroupSheet | TextField |
| `btn_createGroupConfirm` | CreateGroupSheet | Button |
| `field_inviteCode` | JoinGroupSheet | TextField |
| `btn_joinGroupConfirm` | JoinGroupSheet | Button |
| `btn_addSubscription` | SubscriptionListView (toolbar) | Button |
| `field_serviceName` | SubscriptionFormView | TextField |
| `field_amount` | SubscriptionFormView | TextField |
| `btn_saveSubscription` | SubscriptionFormView (toolbar) | Button |
| `text_monthlyTotal` | DashboardView | Text |
| `text_inviteCode` | InviteCodeSheet | Text |
| `picker_baseCurrency` | SettingsView | Picker |
| `btn_signout` | SettingsView | Button |

---

## XCUITest 実行方法

```
Xcode → Product → Test (Cmd+U)
```

必要な環境変数（スキームのTest設定に設定済み、値はユーザーが入力）:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `UAT_TEST_EMAIL`
- `UAT_TEST_PASSWORD`

---

## エラーハンドリング規約

```swift
// RepositoryはAppErrorをthrow
enum AppError: LocalizedError {
    case notAuthenticated
    case notFound
    case networkError(Error)
    // ...
}

// ViewはerrorMessageStateに格納してTextで表示
@State private var errorMessage: String?
// ...
} catch {
    errorMessage = error.localizedDescription
}
```

---

## Supabase クライアント取得

```swift
// シングルトン経由（直接SupabaseClientを使う場合）
let client = SupabaseClientProvider.shared.client

// 通常はRepositoryを経由するため、直接使用しない
```

---

## コードを追加・修正したら

1. Swift 6のWarning/Errorがないことを確認（`Cmd+B`）
2. 対応するUITestが存在するか確認（`SubTrackFamilyUITests/Tests/`）
3. `docs/known-issues.md` の修正済みバグリストを更新
4. `git add` → `git commit` → `git push origin architect`
