import SwiftUI

struct SettingsView: View {

    @Environment(AppEnvironment.self) private var appEnv
    @State private var selectedCurrency: String = "JPY"

    var body: some View {
        NavigationStack {
            List {
                Section("アカウント") {
                    if let user = appEnv.currentUser {
                        LabeledContent("表示名", value: user.displayName)
                    }
                    Button("ログアウト", role: .destructive) {
                        Task {
                            try? await appEnv.authRepository.signOut()
                            appEnv.isAuthenticated = false
                            appEnv.currentUser = nil
                        }
                    }
                }

                Section("表示設定") {
                    Picker("基準通貨", selection: $selectedCurrency) {
                        ForEach(AppConstants.SupportedCurrencies.all, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                }

                Section("アプリ情報") {
                    LabeledContent("バージョン", value: "1.0.0")
                }
            }
            .navigationTitle("設定")
            .onAppear {
                selectedCurrency = appEnv.currentUser?.baseCurrency ?? "JPY"
            }
        }
    }
}
