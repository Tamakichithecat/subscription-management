import SwiftUI

struct AppRouter: View {

    @Environment(AppEnvironment.self) private var appEnv

    var body: some View {
        if appEnv.isAuthenticated {
            MainTabView()
        } else {
            WelcomeView()
        }
    }
}
