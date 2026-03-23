import Foundation

struct UserProfileDTO: Codable, Sendable {
    let id: UUID
    var displayName: String
    var avatarURL: String?
    var baseCurrency: String
    let createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName  = "display_name"
        case avatarURL    = "avatar_url"
        case baseCurrency = "base_currency"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
    }

    func toDomain() -> UserProfile {
        let formatter = ISO8601DateFormatter()
        return UserProfile(
            id: id,
            displayName: displayName,
            avatarURL: avatarURL,
            baseCurrency: baseCurrency,
            createdAt: formatter.date(from: createdAt) ?? Date(),
            updatedAt: formatter.date(from: updatedAt) ?? Date()
        )
    }
}
