# システムアーキテクチャ設計書

**プロジェクト名**: SubTrack Family（仮称）
**作成日**: 2026-03-23
**バージョン**: 1.0

---

## 1. アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────┐
│                     iOS App (Swift/SwiftUI)               │
│                                                           │
│  ┌──────────────────────────────────────────────────┐    │
│  │              Presentation Layer                   │    │
│  │        SwiftUI Views ＋ ViewModels (MVVM)         │    │
│  ├──────────────────────────────────────────────────┤    │
│  │               Domain Layer                        │    │
│  │        Use Cases / Business Logic / Entities      │    │
│  ├──────────────────────────────────────────────────┤    │
│  │                Data Layer                         │    │
│  │    Repositories / Remote DataSource / Local Cache │    │
│  │              (Core Data)                          │    │
│  └──────────────────────────────────────────────────┘    │
└───────────────────────┬─────────────────────────────────┘
                        │ HTTPS / WebSocket (Realtime)
                        ▼
┌─────────────────────────────────────────────────────────┐
│                     Supabase (BaaS)                       │
│                                                           │
│  ┌──────────┐  ┌─────────────┐  ┌────────────────────┐  │
│  │   Auth   │  │  PostgREST  │  │  Realtime (WS)     │  │
│  │(JWT/OAuth│  │  (REST API) │  │  (グループ同期)     │  │
│  └──────────┘  └─────────────┘  └────────────────────┘  │
│                                                           │
│  ┌─────────────────────────────┐  ┌──────────────────┐  │
│  │     PostgreSQL (DB)          │  │  Edge Functions  │  │
│  │  + Row Level Security (RLS)  │  │  (通知・為替取得) │  │
│  └─────────────────────────────┘  └──────────────────┘  │
│                                                           │
│  ┌──────────────────────────────┐                        │
│  │     Storage (アイコン画像等)  │                        │
│  └──────────────────────────────┘                        │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┴─────────────┐
        ▼                          ▼
┌──────────────────┐   ┌─────────────────────────┐
│  APNs (Apple     │   │  Exchange Rate API       │
│  Push Notification│  │  Exchange Rate API       │
│  Service)        │   │   (frankfurter.app)       │
└──────────────────┘   └─────────────────────────┘
```

---

## 2. 技術スタック

### 2.1 iOS クライアント

| 項目 | 技術 | 選定理由 |
|------|------|----------|
| 言語 | Swift 6.0+ | iOS Nativeの標準言語。Xcode 26からSwift 6がデフォルト |
| UI フレームワーク | SwiftUI | 宣言的UI。Xcode 26でLiquid Glass UIが自動適用（iOS 26+） |
| アーキテクチャ | MVVM + Clean Architecture | テスタビリティ・拡張性が高い |
| 非同期処理 | Swift Concurrency (async/await) | モダンな非同期処理。コールバック地獄を回避 |
| リアクティブ | Combine | SwiftUIとの親和性が高い |
| ローカルDB | Core Data | オフラインキャッシュ。Apple標準で安定 |
| パッケージ管理 | Swift Package Manager (SPM) | Xcodeに統合されており標準的 |
| セキュアストレージ | Keychain (KeychainAccess) | 認証トークン・機密情報の安全な保存 |

### 2.2 主要ライブラリ（iOS）

| ライブラリ | 用途 | 取得先 |
|-----------|------|--------|
| `supabase-swift` | Supabase SDK（Auth・DB・Realtime） | github.com/supabase/supabase-swift |
| `Charts` (Swift Charts) | 費用グラフの描画 | Apple標準（iOS 17+） |
| `KeychainAccess` | Keychain操作の簡略化 | github.com/kishikawakatsumi/KeychainAccess |

### 2.3 バックエンド（Supabase）

| サービス | 用途 |
|---------|------|
| Supabase Auth | ユーザー認証（メール・Apple・Google） |
| PostgreSQL | データ永続化 |
| PostgREST | 自動生成REST API |
| Realtime | グループ内のデータ変更をリアルタイム同期 |
| Edge Functions | 通知スケジューラー・為替レート取得 |
| Storage | サービスロゴ画像（将来対応） |
| Row Level Security | グループ外へのデータアクセス制御 |

### 2.4 外部サービス

| サービス | 用途 | 代替 |
|---------|------|------|
| frankfurter.app | 為替レート取得（日次）。APIキー不要・完全無料 | - |
| Apple Push Notification Service (APNs) | プッシュ通知（v1.1以降・Apple Developer Program要） | - |

---

## 3. iOS クライアント内部設計

### 3.1 ディレクトリ構成

```
SubTrackFamily/
├── App/
│   ├── SubTrackFamilyApp.swift        # アプリエントリーポイント
│   └── AppDependencies.swift          # DI コンテナ
│
├── Presentation/                      # UI Layer
│   ├── Auth/
│   │   ├── WelcomeView.swift
│   │   ├── SignInView.swift
│   │   └── AuthViewModel.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   └── DashboardViewModel.swift
│   ├── Subscription/
│   │   ├── SubscriptionListView.swift
│   │   ├── SubscriptionDetailView.swift
│   │   ├── SubscriptionFormView.swift
│   │   └── SubscriptionViewModel.swift
│   ├── ContractList/                  # 契約情報一覧（相続対応）
│   │   ├── ContractListView.swift
│   │   └── ContractListViewModel.swift
│   ├── Family/
│   │   ├── FamilyGroupView.swift
│   │   └── FamilyGroupViewModel.swift
│   ├── Reports/
│   │   ├── ReportsView.swift
│   │   └── ReportsViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
│
├── Domain/                            # Business Logic Layer
│   ├── Entities/
│   │   ├── Subscription.swift
│   │   ├── Group.swift
│   │   ├── User.swift
│   │   └── ExchangeRate.swift
│   ├── UseCases/
│   │   ├── SubscriptionUseCase.swift
│   │   ├── GroupUseCase.swift
│   │   ├── NotificationUseCase.swift
│   │   └── CurrencyUseCase.swift
│   └── Repositories/ (Protocols)
│       ├── SubscriptionRepositoryProtocol.swift
│       ├── GroupRepositoryProtocol.swift
│       └── ExchangeRateRepositoryProtocol.swift
│
├── Data/                              # Data Layer
│   ├── Repositories/
│   │   ├── SubscriptionRepository.swift
│   │   ├── GroupRepository.swift
│   │   └── ExchangeRateRepository.swift
│   ├── Remote/
│   │   ├── SupabaseClient.swift
│   │   └── DTOs/
│   │       ├── SubscriptionDTO.swift
│   │       └── GroupDTO.swift
│   └── Local/
│       ├── CoreDataStack.swift
│       └── Models/                   # Core Data NSManagedObject
│
└── Core/                              # 共通ユーティリティ
    ├── Extensions/
    ├── Constants.swift
    └── Formatters/
        ├── CurrencyFormatter.swift
        └── DateFormatter.swift
```

### 3.2 データフロー

```
User Action
    │
    ▼
SwiftUI View
    │ (calls)
    ▼
ViewModel (@MainActor)
    │ (calls)
    ▼
Use Case
    │ (calls)
    ▼
Repository (Protocol)
    │
    ├── Remote: Supabase API  ──→  PostgreSQL
    └── Local:  Core Data     ──→  SQLite (on device)
```

### 3.3 オフライン対応戦略

1. アプリ起動時、まずローカルキャッシュ（Core Data）を即時表示
2. バックグラウンドでSupabaseから最新データを取得・差分更新
3. オフライン中の変更操作はローカルに保存し、オンライン復帰時に同期
4. 競合解決: サーバー側の `updated_at` を優先（Last Write Wins）

---

## 4. バックエンド設計（Supabase）

### 4.1 Row Level Security (RLS) ポリシー

全テーブルに対し、自分が所属するグループのデータのみアクセス可能なポリシーを設定する。

```sql
-- subscriptions テーブルの RLS 例
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read subscriptions in their group"
  ON subscriptions FOR SELECT
  USING (
    group_id IN (
      SELECT group_id FROM group_members
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Members can insert subscriptions in their group"
  ON subscriptions FOR INSERT
  WITH CHECK (
    group_id IN (
      SELECT group_id FROM group_members
      WHERE user_id = auth.uid()
        AND role IN ('owner', 'member')
    )
  );
```

### 4.2 Edge Functions 一覧

| 関数名 | トリガー | 処理 |
|--------|---------|------|
| `send-renewal-notifications` | 毎日 08:00 JST（cron） | 翌日・3日後・7日後に請求日が来るサブスクを検索しAPNs経由でプッシュ通知 |
| `fetch-exchange-rates` | 毎日 01:00 JST（cron） | Exchange Rate APIから為替レートを取得しDBに保存 |

### 4.3 Realtime 購読設定

グループ内の変更をリアルタイムで家族全員に反映する。

```swift
// iOS側でのRealtime購読例
let channel = supabase.realtime.channel("group:\(groupId)")
channel.on(.postgresChanges, filter: .init(
    event: .all,
    schema: "public",
    table: "subscriptions",
    filter: "group_id=eq.\(groupId)"
)) { payload in
    // サブスク変更を検知してローカルデータを更新
}
channel.subscribe()
```

---

## 5. 通知フロー

```
[Edge Function (Daily Cron)]
        │
        │ 1. 翌日〜7日以内に次回請求日が来るサブスクを検索
        │
        ▼
[PostgreSQL]
        │
        │ 2. 対象サブスクの通知設定を確認
        │    (notification_settings テーブル)
        │
        ▼
[APNs (Apple Push Notification Service)]
        │
        │ 3. device_tokens テーブルからユーザーのデバイストークンを取得
        │    → APNs経由でプッシュ通知を送信
        │
        ▼
[ユーザーのiPhone]
        │
        │ 4. 通知受信 → アプリを開くとサブスク詳細へ遷移
```

---

## 6. 為替レート取得フロー

```
[Edge Function (Daily Cron: 01:00 JST)]
        │
        ▼
[frankfurter.app（APIキー不要）]
  GET /v1/latest?base=JPY
        │
        ▼
[exchange_rates テーブルに UPSERT]
  (base_currency, target_currency, rate, fetched_at)
        │
        ▼
[iOS App]
  - 起動時にキャッシュを読み込む
  - 古いキャッシュ（>24h）の場合は再取得をトリガー
```

---

## 7. セキュリティ設計

| 脅威 | 対策 |
|------|------|
| 不正アクセス | Supabase RLS でグループ外データへのアクセスを DB レベルで遮断 |
| 認証トークン漏洩 | iOS Keychain に保存（ memory には持たない） |
| 機密財務データ | クレジットカード番号・銀行口座番号は保存しない（メモのみ） |
| 通信の盗聴 | 全通信 HTTPS / TLS 1.3 |
| アプリ乗っ取り | Face ID / Touch ID によるアプリロック |
| 招待コードの悪用 | 招待コードは1回使用したら無効化（またはオーナーが都度再発行） |

---

## 8. 開発・デプロイフロー

```
開発者
  │
  ├── feature/* ブランチで開発
  │
  ├── Pull Request → main
  │     ├── SwiftLint（コード品質チェック）
  │     └── Unit Tests（Xcode Cloud または GitHub Actions）
  │
  ├── main マージ → TestFlight 自動配布（Xcode Cloud）
  │
  └── リリースタグ → App Store Connect 審査申請
```

---

## 9. 非機能要件の実現方針

| 要件 | 実現方針 |
|------|---------|
| オフライン対応 | Core Data キャッシュ + バックグラウンド同期 |
| 起動速度 | Core Data から先読みし、Supabase は非同期更新 |
| スケーラビリティ | Supabase（PostgreSQL）はマネージドサービスで自動スケール |
| プライバシー | App Privacy ラベルを適切に設定・財務データは保存しない |
| アクセシビリティ | SwiftUI の標準アクセシビリティ対応（VoiceOver等） |
