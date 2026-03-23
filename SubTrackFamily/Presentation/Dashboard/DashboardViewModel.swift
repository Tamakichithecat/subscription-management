import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {

    // MARK: - State

    var subscriptions: [Subscription] = []
    var exchangeRates: [ExchangeRate] = []
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Computed

    var monthlyTotal: Decimal {
        subscriptionUseCase.monthlyTotal(
            subscriptions: subscriptions,
            rates: exchangeRates,
            baseCurrency: baseCurrency
        )
    }

    var annualTotal: Decimal {
        monthlyTotal * 12
    }

    var upcomingBillings: [Subscription] {
        subscriptionUseCase.upcomingBillings(subscriptions: subscriptions)
    }

    var totalByCategory: [UUID?: Decimal] {
        subscriptionUseCase.totalByCategory(
            subscriptions: subscriptions,
            rates: exchangeRates,
            baseCurrency: baseCurrency
        )
    }

    var activeCount: Int {
        subscriptions.filter { $0.status.isActive }.count
    }

    // MARK: - Dependencies

    private let subscriptionUseCase: SubscriptionUseCase
    private let currencyUseCase: CurrencyUseCase
    let groupID: UUID
    let baseCurrency: String

    // MARK: - Init

    init(
        subscriptionUseCase: SubscriptionUseCase,
        currencyUseCase: CurrencyUseCase,
        groupID: UUID,
        baseCurrency: String
    ) {
        self.subscriptionUseCase = subscriptionUseCase
        self.currencyUseCase     = currencyUseCase
        self.groupID             = groupID
        self.baseCurrency        = baseCurrency
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // subscriptions と exchange rates を並列取得
            async let subs  = subscriptionUseCase.fetchAll(groupID: groupID)
            async let rates = currencyUseCase.fetchRates(base: baseCurrency)
            (subscriptions, exchangeRates) = try await (subs, rates)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
