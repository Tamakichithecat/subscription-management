import Foundation

protocol AuthRepositoryProtocol: Sendable {
    func signIn(email: String, password: String) async throws -> UserProfile
    func signUp(email: String, password: String, displayName: String) async throws -> UserProfile
    func signOut() async throws
    func currentUser() async -> UserProfile?
    func updateProfile(displayName: String?, baseCurrency: String?) async throws -> UserProfile
}
