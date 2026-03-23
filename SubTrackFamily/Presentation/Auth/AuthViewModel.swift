import Foundation
import Observation

@Observable
@MainActor
final class AuthViewModel {

    // MARK: - State

    var email: String = ""
    var password: String = ""
    var displayName: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let authRepository: any AuthRepositoryProtocol
    private let appEnv: AppEnvironment

    init(authRepository: any AuthRepositoryProtocol, appEnv: AppEnvironment) {
        self.authRepository = authRepository
        self.appEnv = appEnv
    }

    // MARK: - Actions

    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let profile = try await authRepository.signIn(email: email, password: password)
            appEnv.currentUser = profile
            appEnv.isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp() async {
        guard !email.isEmpty, !password.isEmpty, !displayName.isEmpty else {
            errorMessage = "すべての項目を入力してください"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let profile = try await authRepository.signUp(
                email: email,
                password: password,
                displayName: displayName
            )
            appEnv.currentUser = profile
            appEnv.isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
