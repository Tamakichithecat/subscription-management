import Foundation

/// Supabase の subscriptions テーブルに対応するDTO
struct SubscriptionDTO: Codable, Sendable {
    let id: UUID
    let groupID: UUID
    var name: String
    var description: String?
    var categoryID: UUID?
    var status: String
    var serviceURL: String?
    var contractorUserID: UUID?
    var paymentMethodNote: String?
    var isImportant: Bool
    var amount: Double          // DB は DECIMAL → Swift では Double で受け取り Decimal に変換
    var currency: String
    var billingCycle: String
    var billingCycleDays: Int?
    var startDate: String?      // ISO 8601 date string
    var nextBillingDate: String
    var endDate: String?
    var autoRenew: Bool
    var notes: String?
    let createdBy: UUID?
    let createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case groupID              = "group_id"
        case name
        case description
        case categoryID           = "category_id"
        case status
        case serviceURL           = "service_url"
        case contractorUserID     = "contractor_user_id"
        case paymentMethodNote    = "payment_method_note"
        case isImportant          = "is_important"
        case amount
        case currency
        case billingCycle         = "billing_cycle"
        case billingCycleDays     = "billing_cycle_days"
        case startDate            = "start_date"
        case nextBillingDate      = "next_billing_date"
        case endDate              = "end_date"
        case autoRenew            = "auto_renew"
        case notes
        case createdBy            = "created_by"
        case createdAt            = "created_at"
        case updatedAt            = "updated_at"
    }

    // MARK: - Mapping

    func toDomain() -> Subscription? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        guard
            let nextBilling = dateFormatter.date(from: nextBillingDate),
            let status = Subscription.Status(rawValue: status),
            let cycle = Subscription.BillingCycle(rawValue: billingCycle)
        else { return nil }

        let fullFormatter = ISO8601DateFormatter()

        return Subscription(
            id: id,
            groupID: groupID,
            name: name,
            description: description,
            categoryID: categoryID,
            status: status,
            serviceURL: serviceURL,
            contractorUserID: contractorUserID,
            paymentMethodNote: paymentMethodNote,
            isImportant: isImportant,
            amount: Decimal(amount),
            currency: currency,
            billingCycle: cycle,
            billingCycleDays: billingCycleDays,
            startDate: startDate.flatMap { dateFormatter.date(from: $0) },
            nextBillingDate: nextBilling,
            endDate: endDate.flatMap { dateFormatter.date(from: $0) },
            autoRenew: autoRenew,
            notes: notes,
            createdBy: createdBy,
            createdAt: fullFormatter.date(from: createdAt) ?? Date(),
            updatedAt: fullFormatter.date(from: updatedAt) ?? Date()
        )
    }
}
