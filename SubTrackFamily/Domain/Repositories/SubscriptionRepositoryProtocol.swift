import Foundation

protocol SubscriptionRepositoryProtocol: Sendable {
    func fetchAll(groupID: UUID) async throws -> [Subscription]
    func fetch(id: UUID) async throws -> Subscription
    func create(_ subscription: Subscription) async throws -> Subscription
    func update(_ subscription: Subscription) async throws -> Subscription
    func delete(id: UUID) async throws
}
