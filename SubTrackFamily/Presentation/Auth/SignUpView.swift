import SwiftUI

struct SignUpView: View {

    @Environment(AppEnvironment.self) private var appEnv
    @State private var viewModel: AuthViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            }
        }
        .onAppear {
            viewModel = AuthViewModel(
                authRepository: appEnv.authRepository,
                appEnv: appEnv
            )
        }
        .navigationTitle("新規登録")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func content(vm: AuthViewModel) -> some View {
        @Bindable var vm = vm
        Form {
            Section("プロフィール") {
                TextField("表示名", text: $vm.displayName)
                    .textContentType(.name)
            }
            Section("アカウント情報") {
                TextField("メールアドレス", text: $vm.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("パスワード（8文字以上）", text: $vm.password)
                    .textContentType(.newPassword)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }

            Section {
                Button {
                    Task { await vm.signUp() }
                } label: {
                    if vm.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("登録する").frame(maxWidth: .infinity)
                    }
                }
                .disabled(vm.isLoading)
            }
        }
    }
}
