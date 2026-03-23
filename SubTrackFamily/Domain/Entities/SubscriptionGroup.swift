import Foundation

struct SubscriptionGroup: Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    let ownerID: UUID
    var inviteCode: String
    let createdAt: Date
}

struct GroupMember: Identifiable, Sendable, Hashable {
    var id: UUID { userID }
    let groupID: UUID
    let userID: UUID
    var role: Role
    let joinedAt: Date

    enum Role: String, Codable, CaseIterable, Sendable {
        case owner  = "owner"
        case member = "member"
        case viewer = "viewer"

        var displayName: String {
            switch self {
            case .owner:  return "オーナー"
            case .member: return "メンバー"
            case .viewer: return "閲覧者"
            }
        }

        var canEdit: Bool {
            self == .owner || self == .member
        }

        var canManageGroup: Bool {
            self == .owner
        }
    }
}
