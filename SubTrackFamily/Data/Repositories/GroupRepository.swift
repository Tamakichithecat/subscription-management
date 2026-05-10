import Foundation
import Supabase

struct GroupRepository: GroupRepositoryProtocol {

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchGroups(userID: UUID) async throws -> [SubscriptionGroup] {
        // group_members 経由で自分が所属するグループを取得
        struct Row: Decodable {
            let groups: GroupDTO
            enum CodingKeys: String, CodingKey { case groups }
        }
        let rows: [Row] = try await client
            .from("group_members")
            .select("groups(*)")
            .eq("user_id", value: userID)
            .execute()
            .value
        return rows.map { $0.groups.toDomain() }
    }

    func fetchMembers(groupID: UUID) async throws -> [GroupMember] {
        let dtos: [GroupMemberDTO] = try await client
            .from("group_members")
            .select()
            .eq("group_id", value: groupID)
            .execute()
            .value
        return dtos.compactMap { $0.toDomain() }
    }

    func createGroup(name: String, ownerID: UUID) async throws -> SubscriptionGroup {
        /* DEBUG: セッション状態を確認（RLS エラー診断用） */
        do {
            let session = try await client.auth.session
            print("✅ [createGroup] session.user.id = \(session.user.id)")
            print("✅ [createGroup] ownerID (arg)   = \(ownerID)")
            print("✅ [createGroup] 一致            = \(session.user.id == ownerID)")
        } catch {
            print("❌ [createGroup] セッションなし: \(error.localizedDescription)")
        }

        struct Insert: Encodable {
            let name: String
            let owner_id: UUID
        }
        let dto: GroupDTO = try await client
            .from("groups")
            .insert(Insert(name: name, owner_id: ownerID))
            .select()
            .single()
            .execute()
            .value
        return dto.toDomain()
    }

    func joinGroup(inviteCode: String, userID: UUID) async throws -> SubscriptionGroup {
        // 招待コードでグループを検索
        let dto: GroupDTO = try await client
            .from("groups")
            .select()
            .eq("invite_code", value: inviteCode)
            .single()
            .execute()
            .value

        // グループメンバーとして追加
        struct MemberInsert: Encodable {
            let group_id: UUID
            let user_id: UUID
            let role: String
        }
        try await client
            .from("group_members")
            .insert(MemberInsert(group_id: dto.id, user_id: userID, role: "member"))
            .execute()

        return dto.toDomain()
    }

    func removeMember(groupID: UUID, userID: UUID) async throws {
        try await client
            .from("group_members")
            .delete()
            .eq("group_id", value: groupID)
            .eq("user_id", value: userID)
            .execute()
    }

    func regenerateInviteCode(groupID: UUID) async throws -> String {
        struct UpdateResult: Decodable { let invite_code: String }
        // PostgreSQL の gen_random_uuid() で新しいコードを生成
        let result: UpdateResult = try await client
            .from("groups")
            .update(["invite_code": AnyJSON.string(UUID().uuidString.prefix(12).lowercased())])
            .eq("id", value: groupID)
            .select("invite_code")
            .single()
            .execute()
            .value
        return result.invite_code
    }

    func updateMemberRole(groupID: UUID, userID: UUID, role: GroupMember.Role) async throws {
        try await client
            .from("group_members")
            .update(["role": AnyJSON.string(role.rawValue)])
            .eq("group_id", value: groupID)
            .eq("user_id", value: userID)
            .execute()
    }
}

// MARK: - DTOs

private struct GroupDTO: Decodable {
    let id: UUID
    let name: String
    let ownerID: UUID
    let inviteCode: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerID    = "owner_id"
        case inviteCode = "invite_code"
        case createdAt  = "created_at"
    }

    func toDomain() -> SubscriptionGroup {
        SubscriptionGroup(
            id: id,
            name: name,
            ownerID: ownerID,
            inviteCode: inviteCode,
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? Date()
        )
    }
}

private struct GroupMemberDTO: Decodable {
    let groupID: UUID
    let userID: UUID
    let role: String
    let joinedAt: String

    enum CodingKeys: String, CodingKey {
        case groupID   = "group_id"
        case userID    = "user_id"
        case role
        case joinedAt  = "joined_at"
    }

    func toDomain() -> GroupMember? {
        guard let role = GroupMember.Role(rawValue: role) else { return nil }
        return GroupMember(
            groupID: groupID,
            userID: userID,
            role: role,
            joinedAt: ISO8601DateFormatter().date(from: joinedAt) ?? Date()
        )
    }
}
