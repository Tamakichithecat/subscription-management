import Foundation

struct Subscription: Identifiable, Sendable, Hashable {

    let id: UUID
    let groupID: UUID
    var name: String
    var description: String?
    var categoryID: UUID?
    var status: Status
    var serviceURL: String?

    // 契約情報（相続対応）
    var contractorUserID: UUID?
    var paymentMethodNote: String?   // 例: "JCBカード（末尾1234）"
    var isImportant: Bool

    // 請求情報
    var amount: Decimal
    var currency: String
    var billingCycle: BillingCycle
    var billingCycleDays: Int?       // cycle == .custom のときのみ使用

    // 日付
    var startDate: Date?
    var nextBillingDate: Date
    var endDate: Date?

    // その他
    var autoRenew: Bool
    var notes: String?

    let createdBy: UUID?
    let createdAt: Date
    var updatedAt: Date

    // MARK: - Nested Types

    enum Status: String, Codable, CaseIterable, Sendable {
        case active    = "active"
        case trial     = "trial"
        case inactive  = "inactive"
        case cancelled = "cancelled"

        var displayName: String {
            switch self {
            case .active:    return "有効"
            case .trial:     return "トライアル"
            case .inactive:  return "一時停止"
            case .cancelled: return "解約済み"
            }
        }

        var isActive: Bool {
            self == .active || self == .trial
        }
    }

    enum BillingCycle: String, Codable, CaseIterable, Sendable {
        case daily      = "daily"
        case weekly     = "weekly"
        case monthly    = "monthly"
        case quarterly  = "quarterly"
        case semiAnnual = "semi_annual"
        case annual     = "annual"
        case custom     = "custom"

        var displayName: String {
            AppConstants.BillingCycle.displayName(for: rawValue)
        }

        /// 月換算の係数（費用集計に使用）
        var monthlyFactor: Decimal {
            switch self {
            case .daily:      return Decimal(365) / 12
            case .weekly:     return Decimal(52) / 12
            case .monthly:    return 1
            case .quarterly:  return Decimal(1) / 3
            case .semiAnnual: return Decimal(1) / 6
            case .annual:     return Decimal(1) / 12
            case .custom:     return 1  // カスタムは呼び出し元で計算
            }
        }
    }

    // MARK: - Computed

    /// 月換算金額
    var monthlyAmount: Decimal {
        amount * billingCycle.monthlyFactor
    }

    /// 年換算金額
    var annualAmount: Decimal {
        monthlyAmount * 12
    }
}
