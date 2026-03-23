import Foundation
import Observation

@Observable
@MainActor
final class SubscriptionViewModel {

    var subscriptions: [Subscription] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var searchText: String = ""
    var selectedStatus: Subscription.Status? = nil

    var filtered: [Subscription] {
        subscriptions
            .filter { sub in
                (searchText.isEmpty || sub.name.localizedCaseInsensitiveContains(searchText))
                && (selectedStatus == nil || sub.status == selectedStatus)
            }
            .sorted { $0.nextBillingDate < $1.nextBillingDate }
    }

    private let useCase: SubscriptionUseCase
    private let groupID: UUID

    init(useCase: SubscriptionUseCase, groupID: UUID) {
        self.useCase = useCase
        self.groupID = groupID
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            subscriptions = try await useCase.fetchAll(groupID: groupID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ subscription: Subscription) async {
        do {
            try await useCase.delete(id: subscription.id)
            subscriptions.removeAll { $0.id == subscription.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
