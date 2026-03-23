import SwiftUI

struct FamilyGroupView: View {

    @Environment(AppEnvironment.self) private var appEnv
    @State private var groups: [SubscriptionGroup] = []
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                if groups.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "グループがありません",
                        systemImage: "person.2",
                        description: Text("グループを作成するか、招待コードで参加してください")
                    )
                } else {
                    ForEach(groups) { group in
                        NavigationLink {
                            GroupDetailView(group: group)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(group.name).font(.headline)
                                Text("招待コード: \(group.inviteCode)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("ファミリー")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showCreateGroup = true } label: {
                            Label("グループを作成", systemImage: "plus")
                        }
                        Button { showJoinGroup = true } label: {
                            Label("招待コードで参加", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupSheet()
            }
            .sheet(isPresented: $showJoinGroup) {
                JoinGroupSheet()
            }
            .overlay { if isLoading { ProgressView() } }
        }
        .task { await loadGroups() }
    }

    private func loadGroups() async {
        guard let userID = appEnv.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }
        groups = (try? await appEnv.groupRepository.fetchGroups(userID: userID)) ?? []
    }
}

// MARK: - Placeholder Sub Views

private struct GroupDetailView: View {
    let group: SubscriptionGroup
    var body: some View {
        List {
            Section("グループ情報") {
                LabeledContent("グループ名", value: group.name)
                LabeledContent("招待コード", value: group.inviteCode)
            }
            // TODO: メンバー一覧・ロール管理
        }
        .navigationTitle(group.name)
    }
}

private struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField("グループ名（例: 田中家）", text: $groupName)
            }
            .navigationTitle("グループを作成")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") { /* TODO */ dismiss() }.disabled(groupName.isEmpty)
                }
            }
        }
    }
}

private struct JoinGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField("招待コードを入力", text: $inviteCode)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .navigationTitle("招待コードで参加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("参加") { /* TODO */ dismiss() }.disabled(inviteCode.isEmpty)
                }
            }
        }
    }
}
