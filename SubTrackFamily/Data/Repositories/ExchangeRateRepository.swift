import Foundation

/// frankfurter.app を利用した為替レートリポジトリ（APIキー不要）
struct ExchangeRateRepository: ExchangeRateRepositoryProtocol {

    // メモリキャッシュ（起動中のみ保持）
    private static var cache: [String: [ExchangeRate]] = [:]

    func fetchRates(base: String) async throws -> [ExchangeRate] {
        // キャッシュが有効なら返す
        if let cached = Self.cache[base], !cached.isEmpty, !(cached.first?.isExpired ?? true) {
            return cached
        }

        let url = URL(string: "\(AppConstants.ExchangeRate.baseURL)/v1/latest?base=\(base)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(FrankfurterResponse.self, from: data)

        let rates = response.rates.map { (targetCurrency, rate) in
            ExchangeRate(
                baseCurrency: base,
                targetCurrency: targetCurrency,
                rate: Decimal(rate),
                fetchedAt: Date()
            )
        }

        Self.cache[base] = rates
        return rates
    }

    func fetchRate(from: String, to: String) async throws -> ExchangeRate {
        let rates = try await fetchRates(base: from)
        guard let rate = rates.first(where: { $0.targetCurrency == to }) else {
            throw AppError.notFound
        }
        return rate
    }
}
