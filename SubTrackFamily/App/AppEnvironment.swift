import Foundation
import Observation
import Supabase

/// アプリ全体で共有する依存関係・状態を保持する環境オブジェクト
@Observable
@MainActor
final class AppEnvironment {

    // MARK: - Auth State

    var isAuthenticated: Bool = false
    var isCheckingSession: Bool = true   // 起動時のセッション確認中フラグ
    var currentUser: UserProfile?

    // MARK: - Group State

    var selectedGroup: SubscriptionGroup?
    var groups: [SubscriptionGroup] = []

    // MARK: - Repositories

    let authRepository: any AuthRepositoryProtocol
    let subscriptionRepository: any SubscriptionRepositoryProtocol
    let groupRepository: any GroupRepositoryProtocol
    let exchangeRateRepository: any ExchangeRateRepositoryProtocol

    // MARK: - Use Cases

    let subscriptionUseCase: SubscriptionUseCase
    let currencyUseCase: CurrencyUseCase

    // MARK: - Realtime

    private var realtimeChannel: RealtimeChannelV2?

    // MARK: - Init

    init() {
        let supabase = SupabaseClientProvider.shared.client

        let authRepo    = AuthRepository(client: supabase)
        let subRepo     = SubscriptionRepository(client: supabase)
        let groupRepo   = GroupRepository(client: supabase)
        let rateRepo    = ExchangeRateRepository()

        self.authRepository          = authRepo
        self.subscriptionRepository  = subRepo
        self.groupRepository         = groupRepo
        self.exchangeRateRepository  = rateRepo
        self.subscriptionUseCase     = SubscriptionUseCase(repository: subRepo)
        self.currencyUseCase         = CurrencyUseCase(repository: rateRepo)
    }

    // MARK: - Session

    /// 起動時に既存セッションを確認して自動ログイン
    func checkSession() async {
        defer { isCheckingSession = false }

        guard let user = await authRepository.currentUser() else { return }

        currentUser = user
        isAuthenticated = true
        await loadGroups(for: user.id)
    }

    // MARK: - Group Management

    /// ユーザーのグループ一覧を読み込み、先頭を selectedGroup に設定
    func loadGroups(for userID: UUID) async {
        let fetched = (try? await groupRepository.fetchGroups(userID: userID)) ?? []
        groups = fetched
        if selectedGroup == nil {
            selectedGroup = fetched.first
        }
        if let group = selectedGroup {
            await startRealtime(for: group.id)
        }
    }

    /// グループを作成してそれを選択状態にする
    func createGroup(name: String) async throws {
        guard let userID = currentUser?.id else { throw AppError.notAuthenticated }
        let group = try await groupRepository.createGroup(name: name, ownerID: userID)
        groups.append(group)
        selectedGroup = group
        await startRealtime(for: group.id)
    }

    /// 招待コードでグループに参加してそれを選択状態にする
    func joinGroup(inviteCode: String) async throws {
        guard let userID = currentUser?.id else { throw AppError.notAuthenticated }
        let group = try await groupRepository.joinGroup(inviteCode: inviteCode, userID: userID)
        if !groups.contains(where: { $0.id == group.id }) {
            groups.append(group)
        }
        selectedGroup = group
        await startRealtime(for: group.id)
    }

    // MARK: - Sign Out

    func signOut() async {
        await stopRealtime()
        try? await authRepository.signOut()
        isAuthenticated = false
        currentUser = nil
        selectedGroup = nil
        groups = []
    }

    // MARK: - Realtime

    /// 選択グループの subscriptions テーブルをリアルタイム購読
    func startRealtime(for groupID: UUID) async {
        await stopRealtime()

        let supabase = SupabaseClientProvider.shared.client
        let channel = supabase.realtimeV2.channel("subscriptions:\(groupID)")

        await channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "subscriptions",
            filter: "group_id=eq.\(groupID)"
        ) { [weak self] _ in
            guard let self else { return }
            // 変更を検知したら通知を発行（各ViewModelが購読して再取得する）
            NotificationCenter.default.post(
                name: .subscriptionsDidChange,
                object: groupID
            )
        }

        await channel.subscribe()
        realtimeChannel = channel
    }

    func stopRealtime() async {
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let subscriptionsDidChange = Notification.Name("subscriptionsDidChange")
}
