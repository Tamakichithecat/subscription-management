import Foundation
import Observation

/// アプリ全体で共有する依存関係・状態を保持する環境オブジェクト
@Observable
final class AppEnvironment {

    // MARK: - Auth State

    var isAuthenticated: Bool = false
    var currentUser: UserProfile?

    // MARK: - Repositories

    let authRepository: any AuthRepositoryProtocol
    let subscriptionRepository: any SubscriptionRepositoryProtocol
    let groupRepository: any GroupRepositoryProtocol
    let exchangeRateRepository: any ExchangeRateRepositoryProtocol

    // MARK: - Use Cases

    let subscriptionUseCase: SubscriptionUseCase
    let currencyUseCase: CurrencyUseCase

    // MARK: - Init

    init() {
        let supabase = SupabaseClientProvider.shared.client

        let authRepo = AuthRepository(client: supabase)
        let subscriptionRepo = SubscriptionRepository(client: supabase)
        let groupRepo = GroupRepository(client: supabase)
        let exchangeRateRepo = ExchangeRateRepository()

        self.authRepository = authRepo
        self.subscriptionRepository = subscriptionRepo
        self.groupRepository = groupRepo
        self.exchangeRateRepository = exchangeRateRepo

        self.subscriptionUseCase = SubscriptionUseCase(repository: subscriptionRepo)
        self.currencyUseCase = CurrencyUseCase(repository: exchangeRateRepo)
    }
}
