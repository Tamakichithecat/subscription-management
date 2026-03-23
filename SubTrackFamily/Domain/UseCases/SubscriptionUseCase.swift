import Foundation

struct SubscriptionUseCase: Sendable {

    private let repository: any SubscriptionRepositoryProtocol

    init(repository: any SubscriptionRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Fetch

    func fetchAll(groupID: UUID) async throws -> [Subscription] {
        try await repository.fetchAll(groupID: groupID)
    }

    // MARK: - Aggregation

    /// 月次総支出をbaseCurrencyに換算して返す
    func monthlyTotal(
        subscriptions: [Subscription],
        rates: [ExchangeRate],
        baseCurrency: String
    ) -> Decimal {
        let active = subscriptions.filter { $0.status.isActive }
        return active.reduce(Decimal.zero) { total, sub in
            let converted = convert(
                amount: sub.monthlyAmount,
                from: sub.currency,
                to: baseCurrency,
                rates: rates
            )
            return total + converted
        }
    }

    /// 年次総支出をbaseCurrencyに換算して返す
    func annualTotal(
        subscriptions: [Subscription],
        rates: [ExchangeRate],
        baseCurrency: String
    ) -> Decimal {
        monthlyTotal(subscriptions: subscriptions, rates: rates, baseCurrency: baseCurrency) * 12
    }

    /// カテゴリー別集計
    func totalByCategory(
        subscriptions: [Subscription],
        rates: [ExchangeRate],
        baseCurrency: String
    ) -> [UUID?: Decimal] {
        let active = subscriptions.filter { $0.status.isActive }
        return Dictionary(grouping: active, by: { $0.categoryID })
            .mapValues { subs in
                subs.reduce(Decimal.zero) { total, sub in
                    total + convert(
                        amount: sub.monthlyAmount,
                        from: sub.currency,
                        to: baseCurrency,
                        rates: rates
                    )
                }
            }
    }

    /// 7日以内に請求日が来るサブスク（昇順）
    func upcomingBillings(subscriptions: [Subscription]) -> [Subscription] {
        subscriptions
            .filter { $0.status.isActive && $0.nextBillingDate.isUpcomingBilling }
            .sorted { $0.nextBillingDate < $1.nextBillingDate }
    }

    // MARK: - CRUD

    func create(_ subscription: Subscription) async throws -> Subscription {
        try await repository.create(subscription)
    }

    func update(_ subscription: Subscription) async throws -> Subscription {
        try await repository.update(subscription)
    }

    func delete(id: UUID) async throws {
        try await repository.delete(id: id)
    }

    // MARK: - Private

    private func convert(
        amount: Decimal,
        from: String,
        to: String,
        rates: [ExchangeRate]
    ) -> Decimal {
        guard from != to else { return amount }
        guard let rate = rates.first(where: {
            $0.baseCurrency == from && $0.targetCurrency == to
        }) else { return amount }
        return amount * rate.rate
    }
}
