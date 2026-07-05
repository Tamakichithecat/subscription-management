# SubTrack Family — AI Agent Entry Point

> このファイルはXcode組み込みClaudeエージェントおよびすべてのAIエージェントのための最初の読み込みファイルです。
> タスクを開始する前に必ずこのファイルを読んでください。

---

## プロジェクト概要

**SubTrack Family** は家族・グループでサブスクリプションを一元管理するiOSアプリです。

- **ターゲット**: iOS 17.0+
- **言語**: Swift 6.0 (Strict Concurrency)
- **UI**: SwiftUI (MVVM + Clean Architecture)
- **バックエンド**: Supabase (PostgreSQL + PostgREST + Realtime)
- **プロジェクト生成**: XcodeGen (`project.yml`)

---

## ドキュメント索引

| ファイル | 内容 |
|---------|------|
| `docs/requirements.md` | 機能要件・非機能要件・ロードマップ |
| `docs/architecture.md` | システム設計・ディレクトリ構成・データフロー |
| `docs/data-model.md` | DBテーブル定義・RLSポリシー・ERD |
| `docs/rls-design.md` | RLS詳細設計と既知のバグ修正履歴（**必読**） |
| `docs/uat.md` | UATテストケース全35件 |
| `docs/known-issues.md` | 既知バグ・未実装機能の一覧 |
| `agent.md` | AIエージェント向け作業ガイドライン |
| `skills.md` | 実装パターン・コーディング規約・ハマりポイント |

---

## ディレクトリ構成（実装済み）

```
subscription-management/
├── CLAUDE.md                          ← このファイル
├── agent.md                           ← AI作業ガイド
├── skills.md                          ← 実装パターン集
├── project.yml                        ← XcodeGen設定
├── docs/                              ← 設計ドキュメント
├── SubTrackFamily/                    ← iOSアプリ本体
│   ├── App/
│   │   ├── SubTrackFamilyApp.swift    ← エントリーポイント
│   │   └── AppEnvironment.swift      ← DI・状態管理（@Observable）
│   ├── Presentation/
│   │   ├── App/
│   │   │   ├── AppRouter.swift        ← 認証状態による画面分岐
│   │   │   └── MainTabView.swift      ← タブバー（5タブ）
│   │   ├── Auth/                      ← WelcomeView, SignInView, SignUpView, AuthViewModel
│   │   ├── Dashboard/                 ← DashboardView, DashboardViewModel
│   │   ├── Subscription/              ← List, Detail, Form, ViewModel
│   │   ├── ContractList/              ← ContractListView（相続対応）
│   │   ├── Family/                    ← FamilyGroupView（グループ管理）
│   │   ├── Group/                     ← GroupSelectionView（初回グループ設定）
│   │   ├── Reports/                   ← ReportsView（グラフ）
│   │   └── Settings/                  ← SettingsView
│   ├── Domain/
│   │   ├── Entities/                  ← Subscription, SubscriptionGroup, UserProfile, ExchangeRate, Category
│   │   ├── UseCases/                  ← SubscriptionUseCase, CurrencyUseCase
│   │   └── Repositories/              ← プロトコル定義
│   ├── Data/
│   │   ├── Repositories/              ← AuthRepository, GroupRepository, SubscriptionRepository, ExchangeRateRepository
│   │   └── Remote/DTOs/               ← SubscriptionDTO, UserProfileDTO
│   └── Core/
│       ├── Constants.swift            ← AppConstants（対応通貨リストなど）
│       ├── Extensions/Date+Billing.swift
│       └── Formatters/CurrencyFormatter.swift
├── SubTrackFamilyUITests/             ← XCUITest（UAT自動化）
│   ├── SubTrackFamilyUITestsBase.swift
│   └── Tests/
│       ├── AUTH_UITests.swift
│       ├── GRP_UITests.swift
│       ├── SUB_UITests.swift
│       ├── DASH_UITests.swift
│       └── VIS_UITests.swift
└── supabase/
    ├── migrations/                    ← 00001〜00012のSQLマイグレーション
    └── seed.sql
```

---

## 主要な状態管理

```
AppEnvironment (@Observable, @MainActor)
  ├── isAuthenticated: Bool
  ├── currentUser: UserProfile?
  ├── selectedGroup: SubscriptionGroup?   ← 現在選択中のグループ
  ├── groups: [SubscriptionGroup]
  ├── authRepository / subscriptionRepository / groupRepository / exchangeRateRepository
  ├── subscriptionUseCase / currencyUseCase
  └── realtimeChannel: RealtimeChannelV2? ← Supabase Realtime購読
```

`AppEnvironment` はアプリ全体で `.environment(appEnv)` として共有されます。
各Viewは `@Environment(AppEnvironment.self) private var appEnv` で参照します。

---

## 画面遷移フロー

```
起動
 └── AppRouter
      ├── isCheckingSession == true  →  ProgressView（スプラッシュ）
      ├── !isAuthenticated           →  WelcomeView → SignIn / SignUp
      ├── isAuthenticated && selectedGroup == nil → GroupSelectionView
      └── isAuthenticated && selectedGroup != nil → MainTabView（5タブ）
           ├── ホーム      → DashboardView
           ├── サブスク     → SubscriptionListView → Detail / Form
           ├── 契約情報     → ContractListView
           ├── ファミリー   → FamilyGroupView
           └── 設定        → SettingsView
```

---

## 開発フロー

```bash
# プロジェクト再生成（project.ymlを変更したとき必須）
xcodegen generate

# ブランチ構成
main       ← リリース用
architect  ← 現在の開発ブランチ（すべての変更はここへ）

# コミット後は architect → main のPRで反映
```

---

## 重要な注意事項

1. **`selectedGroup?.id` を使う** — サブスク・レポートなどグループスコープの操作は必ず `appEnv.selectedGroup?.id` を使用。`currentUser?.id` は誤り。
2. **Swift 6 Strict Concurrency** — `@MainActor` と `async/await` を正しく使用。データ競合はコンパイルエラーになる。
3. **Supabase INSERT後のSELECT** — グループ作成は `.insert().select()` を1リクエストにしてはいけない（RLSタイミングバグ）。必ず2ステップに分ける。詳細は `docs/rls-design.md` を参照。
4. **XcodeGen必須** — `.xcodeproj` は生成物のためGit管理外。変更後は `xcodegen generate` を実行。
5. **UITestの環境変数** — XCUITestはスキームの環境変数（SUPABASE_URL, SUPABASE_ANON_KEY, UAT_TEST_EMAIL, UAT_TEST_PASSWORD）が必要。
