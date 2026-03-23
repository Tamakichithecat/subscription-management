import Foundation

struct UserProfile: Identifiable, Sendable, Hashable {
    let id: UUID
    var displayName: String
    var avatarURL: String?
    var baseCurrency: String
    let createdAt: Date
    var updatedAt: Date
}
