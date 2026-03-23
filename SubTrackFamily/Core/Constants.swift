import Foundation

enum AppConstants {

    enum Supabase {
        /// Supabase プロジェクト URL
        /// 設定方法: Xcode の Scheme > Run > Environment Variables に SUPABASE_URL をセット
        static var url: String {
            ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
        }
        /// Supabase anon key
        static var anonKey: String {
            ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
        }
    }

    enum ExchangeRate {
        static let baseURL = "https://api.frankfurter.app"
        /// キャッシュ有効期限（24時間）
        static let cacheTTLSeconds: TimeInterval = 86_400
    }

    enum SupportedCurrencies {
        static let all: [String] = [
            "JPY", "USD", "EUR", "GBP",
            "AUD", "CAD", "CHF", "CNY", "KRW", "SGD"
        ]
        static let defaultCurrency = "JPY"
    }

    enum BillingCycle {
        static let allCases: [String] = [
            "daily", "weekly", "monthly",
            "quarterly", "semi_annual", "annual", "custom"
        ]

        static func displayName(for cycle: String) -> String {
            switch cycle {
            case "daily":       return "毎日"
            case "weekly":      return "毎週"
            case "monthly":     return "毎月"
            case "quarterly":   return "3ヶ月ごと"
            case "semi_annual": return "6ヶ月ごと"
            case "annual":      return "毎年"
            case "custom":      return "カスタム"
            default:            return cycle
            }
        }
    }
}
