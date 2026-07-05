# システムアーキテクチャ設計書

**プロジェクト名**: SubTrack Family
**最終更新**: 2026-07-05
**バージョン**: 1.1（実装済み状態に合わせて更新）

---

## 1. アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────┐
│                     iOS App (Swift 6 / SwiftUI)           │
│                                                           │
│  ┌──────────────────────────────────────────────────┐    │
│  │              Presentation Layer                   │    │
│  │        SwiftUI Views ＋ ViewModels (MVVM)         │    │
│  ├──────────────────────────────────────────────────┤    │
│  │               Domain Layer                        │    │
│  │        Use Cases / Business Logic / Entities      │    │
│  ├──────────────────────────────────────────────────┤    │
│  │                Data Layer                         │    │
│  │    Repositories / Remote DataSource (Supabase)    │    │
│  │    ※ Core Data は v1.0 未実装                     │    │
│  └──────────────────────────────────────────────────┘    │
└───────────────────────┬─────────────────────────────────┘
                        │ HTTPS / WebSocket (Realtime)
                        ▼
┌─────────────────────────────────────────────────────────┐
│                     Supabase (BaaS)                       │
│                                                           │
│  ┌──────────┐  ┌─────────────┐  ┌────────────────────┐  │
│  │   Auth   │  │  PostgREST  │  │  Realtime (WS)     │  │
│  │(JWT)     │  │  (REST API) │  │  (subscriptions同期)│  │
│  └──────────┘  └─────────────┘  └────────────────────┘  │
│                                                           │
│  ┌─────────────────────────────┐                         │
│  │     PostgreSQL (DB)          │                         │
│  │  + Row Level Security (RLS)  │                         │
│  └─────────────────────────────┘                         │
└─────────────────────────────────────────────────────────┘
                        │
              ┌─────────┴──────────┐
              ▼                    ▼
┌─────────────────┐   ┌───────────────────────┐
│  APNs (将来v1.1) │   │  frankfurter.app       │
│  プッシュ通知     │   │  為替レートAPI（無料）  │
└─────────────────┘   └───────────────────────┘
```

---

## 2. 技術スタック

### 2.1 iOS クライアント

| 項目 | 技術 |
|------|------|
| 言語 | Swift 6.0（Strict Concurrency有効） |
| UI フレームワーク | SwiftUI |
| アーキテクチャ | MVVM + Clean Architecture |
| 状態管理 | @Observable（iOS 17+ マクロ）、AppEnvironment で DI・状態を集中管理 |
| 非同期処理 | Swift Concurrency（async/await, @MainActor） |
| ローカルDB | **なし（v1.0）** ※Core Dataはv2.0検討 |
| パッケージ管理 | Swift Package Manager（XcodeGen経由） |
| セキュアストレージ | Keychain（KeychainAccess ライブラリ） |

### 2.2 主要ライブラリ

| ライブラリ | バージョン | 用途 |
|-----------|-----------|------|
| `supabase-swift` | 2.0.0+ | Auth・DB・Realtime |
| `KeychainAccess` | 4.2.2+ | Keychain操作 |
| `Swift Charts` | Apple標準（iOS 17+） | ダッシュボード・レポートのグラフ |

### 2.3 バックエンド（Supabase）

| サービス | 用途 | v1.0 実装状態 |
|---------|------|--------------|
| Supabase Auth | ユーザー認証（メール+パスワード） | ✅ 実装済み |
| PostgreSQL | データ永続化 | ✅ 実装済み |
| PostgREST | 自動生成REST API | ✅ 実装済み |
| Realtime | subscriptionsテーブルの変更通知 | ✅ 実装済み |
| Edge Functions | 通知・為替レート取得 | ❌ v1.1以降 |
| Storage | サービスロゴ画像 | ❌ 未対応 |
| Row Level Security | グループ外データアクセス制御 | ✅ 実装済み |

---

## 3. iOS クライアント内部設計

### 3.1 ディレクトリ構成（v1.0 実装済み）

```
SubTrackFamily/
├── App/
│   ├── SubTrackFamilyApp.swift        # アプリエントリーポイント
│   └── AppEnvironment.swift           # DI コンテナ・状態管理（@Observable）
│
├── Presentation/
│   ├── App/
│   │   ├── AppRouter.swift             # 認証状態による画面分岐
│   │   └── MainTabView.swift           # タブバー（5タブ）
│   ├── Auth/
│   │   ├── WelcomeView.swift           # ロゴ・ログイン/新規登録ボタン
│   │   ├── SignInView.swift            # メールログイン
│   │   ├── SignUpView.swift            # 新規登録
│   │   └── AuthViewModel.swift        # ✅ @Observableで状態管理
│   ├── Dashboard/
│   │   ├── DashboardView.swift         # 月次サマリー・更新予定
│   │   └── DashboardViewModel.swift   # ✅ @Observableで状態管理
│   ├── Subscription/
│   │   ├── SubscriptionListView.swift  # 一覧・検索・フィルタ
│   │   ├── SubscriptionDetailView.swift # 詳細表示・編集導線
│   │   ├── SubscriptionFormView.swift  # 追加・編集フォーム
│   │   └── SubscriptionViewModel.swift # ✅ @Observableで状態管理
│   ├── ContractList/
│   │   └── ContractListView.swift      # 契約情報一覧（相続対応）※ViewModelなし
│   ├── Family/
│   │   └── FamilyGroupView.swift       # グループ管理・メンバー一覧 ※ViewModelなし
│   ├── Group/
│   │   └── GroupSelectionView.swift    # 初回グループ設定（作成/参加）
│   ├── Reports/
│   │   └── ReportsView.swift           # 費用グラフ ※タブ未接続
│   └── Settings/
│       └── SettingsView.swift          # 基準通貨・ログアウト
│
├── Domain/
│   ├── Entities/
│   │   ├── Subscription.swift          # サブスク本体（BillingCycle, Status 等のネスト型含む）
│   │   ├── SubscriptionGroup.swift     # グループ
│   │   ├── UserProfile.swift           # ユーザー
│   │   ├── ExchangeRate.swift          # 為替レート
│   │   └── Category.swift             # カテゴリー
│   ├── UseCases/
│   │   ├── SubscriptionUseCase.swift   # CRUD・月換算金額算出
│   │   └── CurrencyUseCase.swift       # 為替レート取得・キャッシュ
│   └── Repositories/ (Protocols)
│       ├── AuthRepositoryProtocol.swift
│       ├── SubscriptionRepositoryProtocol.swift
│       ├── GroupRepositoryProtocol.swift
│       └── ExchangeRateRepositoryProtocol.swift
│
├── Data/
│   ├── Repositories/
│   │   ├── AuthRepository.swift        # Supabase Auth
│   │   ├── SubscriptionRepository.swift # subscriptionsテーブルCRUD
│   │   ├── GroupRepository.swift       # groupsテーブル（2ステップINSERT実装済み）
│   │   └── ExchangeRateRepository.swift # frankfurter.app API
│   └── Remote/
│       ├── SupabaseClientProvider.swift # シングルトン
│       └── DTOs/
│           ├── SubscriptionDTO.swift
│           └── UserProfileDTO.swift
│
└── Core/
    ├── Constants.swift                  # AppConstants（通貨リスト等）
    ├── Extensions/
    │   └── Date+Billing.swift           # billingDaysLabel, isUpcomingBilling 等
    └── Formatters/
        └── CurrencyFormatter.swift      # 通貨フォーマット
```

### 3.2 AppEnvironment の役割

```swift
// AppEnvironment は @Observable + @MainActor で全ビューに共有される
// アクセス: @Environment(AppEnvironment.self) private var appEnv

AppEnvironment {
    // Auth state
    isAuthenticated: Bool
    isCheckingSession: Bool
    currentUser: UserProfile?

    // Group state（最重要）
    selectedGroup: SubscriptionGroup?   // ← グループスコープの操作はここから取得
    groups: [SubscriptionGroup]

    // Repositories（DIコンテナ）
    authRepository / subscriptionRepository / groupRepository / exchangeRateRepository

    // Use Cases
    subscriptionUseCase / currencyUseCase

    // Realtime
    realtimeChannel: RealtimeChannelV2?
}
```

### 3.3 データフロー

```
User Action（View）
    │
    ▼
ViewModel (@MainActor)
    │ calls
    ▼
UseCase
    │ calls
    ▼
Repository (Protocol実装)
    │
    └── Remote: Supabase PostgREST API → PostgreSQL
```

Realtime（双方向）:
```
PostgreSQL（subscriptions変更）
    │ WebSocket
    ▼
Supabase Realtime
    │ channel.onPostgresChange
    ▼
AppEnvironment
    │ NotificationCenter.post(.subscriptionsDidChange)
    ▼
各ViewModel → load() を再実行
```

---

## 4. 画面遷移フロー

```
起動 → SubTrackFamilyApp → AppEnvironment.checkSession()
         │
         ▼
       AppRouter
         ├── isCheckingSession == true   → ProgressView（スプラッシュ）
         ├── !isAuthenticated            → WelcomeView
         │     ├── 「ログイン」          → SignInView
         │     └── 「新規登録」          → SignUpView
         ├── isAuthenticated
         │   && selectedGroup == nil     → GroupSelectionView
         │         ├── 「グループを作成」 → CreateGroupSheet
         │         └── 「招待コードで参加」→ JoinGroupSheet
         └── isAuthenticated
             && selectedGroup != nil     → MainTabView（5タブ）
```

---

## 5. セキュリティ設計

| 脅威 | 対策 | 実装状態 |
|------|------|---------|
| 不正アクセス | Supabase RLS でグループ外データへのアクセスを DB レベルで遮断 | ✅ |
| 認証トークン漏洩 | iOS Keychain に保存（KeychainAccess） | ✅ |
| 機密財務データ | クレカ番号・銀行口座番号は保存しない（メモのみ） | ✅（設計上） |
| 通信の盗聴 | 全通信 HTTPS / TLS | ✅（Supabase標準） |
| アプリ乗っ取り | Face ID / Touch ID によるアプリロック | ❌ v1.1以降 |
| 招待コード悪用 | オーナーが任意のタイミングで再生成可能 | ✅ |

詳細は `docs/rls-design.md` を参照。

---

## 6. 非機能要件の実現状況

| 要件 | 実現方針 | v1.0 実装状態 |
|------|---------|--------------|
| オフライン対応 | Core Data キャッシュ | ❌ v2.0検討 |
| 起動速度 | Supabaseから非同期取得、ProgressViewで待機 | ⚠️（キャッシュなし） |
| スケーラビリティ | Supabase マネージドサービス | ✅ |
| プライバシー | App Privacy ラベル設定・財務データ非保存 | 設定要（App Store申請時） |
| アクセシビリティ | accessibilityIdentifier付与済み（UITest用） | ✅ |

---

## 7. 開発・デプロイフロー

```
feature/* または architect ブランチで開発
    │
    ├── GitHub Actions（on push to architect）
    │     └── auto-PR作成（Pull Request へ）
    │
    ├── Pull Request → main
    │     └── レビュー・承認
    │
    └── main → TestFlight / App Store（将来対応）
```

### XcodeGen ワークフロー

```bash
# project.yml を変更したとき必ず実行
xcodegen generate

# UITest実行
Cmd+U（スキームに環境変数を設定済みであること）
```
