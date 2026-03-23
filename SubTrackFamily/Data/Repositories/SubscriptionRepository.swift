import Foundation
import Supabase

struct SubscriptionRepository: SubscriptionRepositoryProtocol {

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchAll(groupID: UUID) async throws -> [Subscription] {
        let dtos: [SubscriptionDTO] = try await client
            .from("subscriptions")
            .select()
            .eq("group_id", value: groupID)
            .order("next_billing_date", ascending: true)
            .execute()
            .value
        return dtos.compactMap { $0.toDomain() }
    }

    func fetch(id: UUID) async throws -> Subscription {
        let dto: SubscriptionDTO = try await client
            .from("subscriptions")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        guard let subscription = dto.toDomain() else {
            throw AppError.invalidData
        }
        return subscription
    }

    func create(_ subscription: Subscription) async throws -> Subscription {
        let dto = toDTO(subscription)
        let created: SubscriptionDTO = try await client
            .from("subscriptions")
            .insert(dto)
            .select()
            .single()
            .execute()
            .value
        guard let result = created.toDomain() else {
            throw AppError.invalidData
        }
        return result
    }

    func update(_ subscription: Subscription) async throws -> Subscription {
        let dto = toDTO(subscription)
        let updated: SubscriptionDTO = try await client
            .from("subscriptions")
            .update(dto)
            .eq("id", value: subscription.id)
            .select()
            .single()
            .execute()
            .value
        guard let result = updated.toDomain() else {
            throw AppError.invalidData
        }
        return result
    }

    func delete(id: UUID) async throws {
        try await client
            .from("subscriptions")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Private

    private func toDTO(_ s: Subscription) -> SubscriptionDTO {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let fullFormatter = ISO8601DateFormatter()

        return SubscriptionDTO(
            id: s.id,
            groupID: s.groupID,
            name: s.name,
            description: s.description,
            categoryID: s.categoryID,
            status: s.status.rawValue,
            serviceURL: s.serviceURL,
            contractorUserID: s.contractorUserID,
            paymentMethodNote: s.paymentMethodNote,
            isImportant: s.isImportant,
            amount: NSDecimalNumber(decimal: s.amount).doubleValue,
            currency: s.currency,
            billingCycle: s.billingCycle.rawValue,
            billingCycleDays: s.billingCycleDays,
            startDate: s.startDate.map { dateFormatter.string(from: $0) },
            nextBillingDate: dateFormatter.string(from: s.nextBillingDate),
            endDate: s.endDate.map { dateFormatter.string(from: $0) },
            autoRenew: s.autoRenew,
            notes: s.notes,
            createdBy: s.createdBy,
            createdAt: fullFormatter.string(from: s.createdAt),
            updatedAt: fullFormatter.string(from: s.updatedAt)
        )
    }
}
