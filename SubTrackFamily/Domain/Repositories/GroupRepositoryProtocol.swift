import Foundation

protocol GroupRepositoryProtocol: Sendable {
    func fetchGroups(userID: UUID) async throws -> [SubscriptionGroup]
    func fetchMembers(groupID: UUID) async throws -> [GroupMember]
    func createGroup(name: String, ownerID: UUID) async throws -> SubscriptionGroup
    func joinGroup(inviteCode: String, userID: UUID) async throws -> SubscriptionGroup
    func removeMember(groupID: UUID, userID: UUID) async throws
    func regenerateInviteCode(groupID: UUID) async throws -> String
    func updateMemberRole(groupID: UUID, userID: UUID, role: GroupMember.Role) async throws
}
