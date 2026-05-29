import SwiftUI

/// ログイン済みだがグループ未所属の場合に表示される画面
struct GroupSelectionView: View {

    @Environment(AppEnvironment.self) private var appEnv
    @State private var showCreate = false
    @State private var showJoin   = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    Text("ファミリーグループに参加しましょう")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                    Text("グループを作成するか、\n招待コードで家族のグループに参加してください")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showCreate = true
                    } label: {
                        Label("グループを作成する", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("btn_createGroup")

                    Button {
                        showJoin = true
                    } label: {
                        Label("招待コードで参加する", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("btn_joinGroup")

                    Button("ログアウト", role: .destructive) {
                        Task { await appEnv.signOut() }
                    }
                    .font(.footnote)
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                .padding(.bottom, 48)
            }
            .navigationTitle("グループ設定")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCreate) { CreateGroupSheet() }
            .sheet(isPresented: $showJoin)   { JoinGroupSheet() }
        }
    }
}

// MARK: - Create Group Sheet

struct CreateGroupSheet: View {

    @Environment(AppEnvironment.self) private var appEnv
    @Environment(\.dismiss) private var dismiss

    @State private var groupName    = ""
    @State private var isLoading    = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例：田中家", text: $groupName)
                        .accessibilityIdentifier("field_groupName")
                } header: {
                    Text("グループ名")
                } footer: {
                    Text("家族全員が同じグループに参加することでサブスクを共有できます")
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("グループを作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        Task { await create() }
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    .accessibilityIdentifier("btn_createGroupConfirm")
                }
            }
        }
    }

    private func create() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await appEnv.createGroup(name: groupName.trimmingCharacters(in: .whitespaces))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Join Group Sheet

struct JoinGroupSheet: View {

    @Environment(AppEnvironment.self) private var appEnv
    @Environment(\.dismiss) private var dismiss

    @State private var inviteCode   = ""
    @State private var isLoading    = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("招待コードを入力", text: $inviteCode)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(.body, design: .monospaced))
                        .accessibilityIdentifier("field_inviteCode")
                } header: {
                    Text("招待コード")
                } footer: {
                    Text("グループオーナーから受け取った招待コードを入力してください")
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("招待コードで参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("参加") {
                        Task { await join() }
                    }
                    .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    .accessibilityIdentifier("btn_joinGroupConfirm")
                }
            }
        }
    }

    private func join() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await appEnv.joinGroup(inviteCode: inviteCode.trimmingCharacters(in: .whitespaces))
            dismiss()
        } catch {
            errorMessage = "招待コードが正しくないか、既に参加済みです"
        }
    }
}
