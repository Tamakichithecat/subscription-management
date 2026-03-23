import Foundation

protocol ExchangeRateRepositoryProtocol: Sendable {
    /// base通貨に対する全通貨のレートを取得（キャッシュ優先）
    func fetchRates(base: String) async throws -> [ExchangeRate]
    /// 特定の通貨ペアのレートを取得
    func fetchRate(from: String, to: String) async throws -> ExchangeRate
}
