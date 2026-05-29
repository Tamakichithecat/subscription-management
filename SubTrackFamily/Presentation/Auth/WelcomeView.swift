import SwiftUI

struct WelcomeView: View {

    @State private var showSignIn = false
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // ロゴ
                VStack(spacing: 12) {
                    Image(systemName: "creditcard.and.123")
                        .font(.system(size: 72))
                        .foregroundStyle(.tint)
                    Text("SubTrack Family")
                        .font(.largeTitle.bold())
                    Text("家族のサブスクを、一目で管理")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // ボタン
                VStack(spacing: 12) {
                    Button {
                        showSignIn = true
                    } label: {
                        Text("ログイン")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("btn_signin")

                    Button {
                        showSignUp = true
                    } label: {
                        Text("新規登録")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("btn_signup")
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationDestination(isPresented: $showSignIn) { SignInView() }
            .navigationDestination(isPresented: $showSignUp) { SignUpView() }
        }
    }
}
