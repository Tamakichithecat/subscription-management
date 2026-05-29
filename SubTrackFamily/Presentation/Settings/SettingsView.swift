import SwiftUI

struct SettingsView: View {

    @Environment(AppEnvironment.self) private var appEnv
    @State private var selectedCurrency: String = AppConstants.SupportedCurrencies.defaultCurrency
    @State private var isSaving = false
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            List {
                // プロフィール
                Section("アカウント") {
                    if let user = appEnv.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading) {
                                Text(user.displayName).font(.headline)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityIdentifier("btn_signout")
                }

                // 表示設定
                Section {
                    Picker("基準通貨", selection: $selectedCurrency) {
                        ForEach(AppConstants.SupportedCurrencies.all, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    .onChange(of: selectedCurrency) { _, newValue in
                        Task { await saveCurrency(newValue) }
                    }
                    .accessibilityIdentifier("picker_baseCurrency")
                } header: {
                    Text("表示設定")
                } footer: {
                    Text("全てのサブスク費用をこの通貨に換算して表示します")
                }

                // アプリ情報
                Section("アプリ情報") {
                    LabeledContent("バージョン", value: "1.0.0")
                    LabeledContent("最小対応OS", value: "iOS 17.0")
                }
            }
            .navigationTitle("設定")
            .onAppear {
                selectedCurrency = appEnv.currentUser?.baseCurrency
                    ?? AppConstants.SupportedCurrencies.defaultCurrency
            }
            .confirmationDialog("ログアウトしますか？", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("ログアウト", role: .destructive) {
                    Task { await appEnv.signOut() }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private func saveCurrency(_ currency: String) async {
        isSaving = true
        defer { isSaving = false }
        if let updated = try? await appEnv.authRepository.updateProfile(
            displayName: nil,
            baseCurrency: currency
        ) {
            appEnv.currentUser = updated
        }
    }
}
