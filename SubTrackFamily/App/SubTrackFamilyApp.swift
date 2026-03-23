import SwiftUI

@main
struct SubTrackFamilyApp: App {

    @State private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(appEnvironment)
        }
    }
}
