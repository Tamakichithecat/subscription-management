import Foundation

struct CurrencyUseCase: Sendable {

    private let repository: any ExchangeRateRepositoryProtocol

    init(repository: any ExchangeRateRepositoryProtocol) {
        self.repository = repository
    }

    func fetchRates(base: String) async throws -> [ExchangeRate] {
        try await repository.fetchRates(base: base)
    }

    func convert(amount: Decimal, from: String, to: String) async throws -> Decimal {
        guard from != to else { return amount }
        let rate = try await repository.fetchRate(from: from, to: to)
        return amount * rate.rate
    }
}
