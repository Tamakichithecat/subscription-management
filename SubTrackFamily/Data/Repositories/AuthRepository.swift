import Foundation
import Supabase

struct AuthRepository: AuthRepositoryProtocol {

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func signIn(email: String, password: String) async throws -> UserProfile {
        let session = try await client.auth.signIn(email: email, password: password)
        return try await fetchProfile(userID: session.user.id)
    }

    func signUp(email: String, password: String, displayName: String) async throws -> UserProfile {
        let session = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["display_name": .string(displayName)]
        )
        return try await fetchProfile(userID: session.user.id)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func currentUser() async -> UserProfile? {
        guard let session = try? await client.auth.session else { return nil }
        return try? await fetchProfile(userID: session.user.id)
    }

    func updateProfile(displayName: String?, baseCurrency: String?) async throws -> UserProfile {
        guard let userID = try? await client.auth.session.user.id else {
            throw AppError.notAuthenticated
        }
        var updates: [String: AnyJSON] = [:]
        if let name = displayName { updates["display_name"] = .string(name) }
        if let currency = baseCurrency { updates["base_currency"] = .string(currency) }

        let dto: UserProfileDTO = try await client
            .from("profiles")
            .update(updates)
            .eq("id", value: userID)
            .select()
            .single()
            .execute()
            .value

        return dto.toDomain()
    }

    // MARK: - Private

    private func fetchProfile(userID: UUID) async throws -> UserProfile {
        let dto: UserProfileDTO = try await client
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .single()
            .execute()
            .value
        return dto.toDomain()
    }
}

// MARK: - AppError

enum AppError: LocalizedError {
    case notAuthenticated
    case notFound
    case invalidData

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "ログインが必要です"
        case .notFound:         return "データが見つかりません"
        case .invalidData:      return "データの形式が正しくありません"
        }
    }
}
