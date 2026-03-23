import SwiftUI

struct SignInView: View {

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
        .navigationTitle("ログイン")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func content(vm: AuthViewModel) -> some View {
        @Bindable var vm = vm
        Form {
            Section {
                TextField("メールアドレス", text: $vm.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("パスワード", text: $vm.password)
                    .textContentType(.password)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button {
                    Task { await vm.signIn() }
                } label: {
                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("ログイン")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(vm.isLoading)
            }
        }
    }
}
