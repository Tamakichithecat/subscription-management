import Foundation

struct ExchangeRate: Sendable, Hashable {
    let baseCurrency: String
    let targetCurrency: String
    let rate: Decimal
    let fetchedAt: Date

    var isExpired: Bool {
        Date().timeIntervalSince(fetchedAt) > AppConstants.ExchangeRate.cacheTTLSeconds
    }
}

/// frankfurter.app のレスポンス形式
struct FrankfurterResponse: Decodable, Sendable {
    let base: String
    let date: String
    let rates: [String: Double]
}
