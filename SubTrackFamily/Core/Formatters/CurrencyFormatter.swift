import Foundation

struct CurrencyFormatter {

    static func string(amount: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = currencyCode == "JPY" || currencyCode == "KRW" ? 0 : 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currencyCode) \(amount)"
    }

    /// 円換算後の金額を表示
    /// - Parameters:
    ///   - amount: 元の金額
    ///   - fromCurrency: 元の通貨
    ///   - rate: 換算レート（fromCurrency → JPY）
    static func convertedString(amount: Decimal, fromCurrency: String, rate: Decimal) -> String {
        let converted = amount * rate
        return string(amount: converted, currencyCode: "JPY")
    }
}
