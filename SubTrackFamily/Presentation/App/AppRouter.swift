import SwiftUI

struct AppRouter: View {

    @Environment(AppEnvironment.self) private var appEnv

    var body: some View {
        Group {
            if appEnv.isCheckingSession {
                // 起動時のセッション確認中：スプラッシュ表示
                SplashView()
            } else if !appEnv.isAuthenticated {
                // 未ログイン
                WelcomeView()
            } else if appEnv.selectedGroup == nil {
                // ログイン済みだがグループ未所属
                GroupSelectionView()
            } else {
                // 通常画面
                MainTabView()
            }
        }
        .task {
            await appEnv.checkSession()
        }
    }
}

// MARK: - Splash View

private struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.and.123")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("SubTrack Family")
                .font(.title2.bold())
            ProgressView()
                .padding(.top, 8)
        }
    }
}
