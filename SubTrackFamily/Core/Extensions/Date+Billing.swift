import Foundation

extension Date {

    /// 次回請求日までの残り日数
    var daysUntilBilling: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: self)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }

    /// 請求日が近い（7日以内）
    var isUpcomingBilling: Bool {
        let days = daysUntilBilling
        return days >= 0 && days <= 7
    }

    /// 請求日が今日
    var isBillingToday: Bool {
        daysUntilBilling == 0
    }

    /// 表示用の残り日数文字列
    var billingDaysLabel: String {
        let days = daysUntilBilling
        switch days {
        case ..<0:  return "期限切れ"
        case 0:     return "今日"
        case 1:     return "明日"
        default:    return "\(days)日後"
        }
    }
}
