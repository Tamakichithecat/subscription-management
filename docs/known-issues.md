# Known Issues & Implementation Status

**最終更新**: 2026-07-05

---

## 修正済みバグ

| ID | 内容 | 修正ファイル | 修正日 |
|----|------|------------|--------|
| BUG-001 | グループ作成時にRLSエラー（PostgREST CTE + AFTER INSERT トリガーのタイミング問題） | `Data/Repositories/GroupRepository.swift` | 2026-06 |
| BUG-002 | サブスク追加ボタンが機能しない（`currentUser?.id` を `groupID` として誤使用） | `Presentation/Subscription/SubscriptionFormView.swift` | 2026-06 |
| BUG-003 | サブスク追加フォームでメモフィールドまでスクロールできない | `Presentation/Subscription/SubscriptionFormView.swift` | 2026-06 |
| BUG-004 | ReportsView でサブスク一覧が表示されない（`currentUser?.id` を `groupID` として誤使用） | `Presentation/Reports/ReportsView.swift` | 2026-07 |
| BUG-005 | GitHub Actions auto-PR が "Resource not accessible by integration" エラー | `.github/workflows/auto-pr.yml` | 2026-06（手動修正） |

---

## 既知の不具合（未修正）

| ID | 内容 | 影響画面 | 優先度 |
|----|------|---------|--------|
| BUG-006 | カテゴリー別グラフのラベルがUUIDで表示される（カテゴリー名に解決されていない） | DashboardView | 中 |

**BUG-006 詳細**:
`DashboardViewModel` の `totalByCategory` が `categoryID: UUID?` をキーにしており、
カテゴリー名に変換するロジックが実装されていない。
修正方針: `categories` テーブルからカテゴリー一覧を取得して `[UUID: String]` マップを作成し、
グラフのラベル生成時に参照する。

---

## 未実装機能（v1.0スコープ外）

| ID | 機能 | 要件ID | 画面 | 対応予定 |
|----|------|--------|------|---------|
| TODO-001 | カテゴリーピッカー（サブスク追加/編集フォーム） | SUB-4 | SubscriptionFormView | v1.1 |
| TODO-002 | 契約者ピッカー（サブスク追加/編集フォーム） | SUB-5 | SubscriptionFormView | v1.1 |
| TODO-003 | パスワードリセット画面 | AUTH-5 | 未作成 | v1.1 |
| TODO-004 | プッシュ通知（更新日前リマインド） | NOTIF-1〜5 | 未作成 | v1.1（Apple Developer Program要） |
| TODO-005 | ReportsViewのタブへの組み込み | - | MainTabView | v1.1 |
| TODO-006 | カテゴリー別支出グラフのラベル修正（BUG-006の修正と同時実施） | DASH-2 | DashboardView | v1.1 |
| TODO-007 | PDFエクスポート（サブスク一覧） | VIS-4 | 未作成 | v1.2 |
| TODO-008 | Sign in with Apple | AUTH-2 | WelcomeView | v1.1 |
| TODO-009 | Face ID / Touch ID によるアプリロック | AUTH-4 | 未作成 | v1.1 |
| TODO-010 | オフラインキャッシュ（Core Data） | 非機能要件 | 全画面 | v2.0検討 |

---

## 設計との差異（実装済みv1.0）

| 設計書の記載 | 実際の実装 | 備考 |
|------------|-----------|------|
| Core Data によるオフラインキャッシュ | **未実装**（Supabaseのみ） | v1.0では省略 |
| ContractListViewModel | **未実装**（ViewにロジックをインラインUIで実装） | 小規模のため許容 |
| FamilyGroupViewModel | **未実装**（同上） | 小規模のため許容 |
| ReportsViewModel | **未実装**（同上） | 小規模のため許容 |
| Edge Functions（通知・為替） | **未実装** | v1.1で実装予定 |
| APNs プッシュ通知 | **未実装** | Apple Developer Program登録後に実装 |
| `Reports` タブ | MainTabViewに含まれていない | 手動でNavigationStackから遷移 |

---

## XCUITest スキップケース

以下のテストケースは現バージョンでは自動実行不可のため `XCTSkip` で除外済み。

| テストID | 理由 |
|---------|------|
| AUTH-1-5 | パスワードリセットUI未実装 |
| GRP-3-1 | 別アカウントの招待コードが必要（手動準備が必要） |
| GRP-4-1 | 複数メンバー参加が必要（手動準備が必要） |
| SUB-4 | カテゴリピッカー未実装 |
| SUB-5 | 契約者ピッカー未実装 |
| CUR-1 | ReportsViewのBUG-004修正後に要再確認 |
