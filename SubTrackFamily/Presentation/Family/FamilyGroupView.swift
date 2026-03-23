import SwiftUI

struct FamilyGroupView: View {

    @Environment(AppEnvironment.self) private var appEnv
    @State private var members: [GroupMember] = []
    @State private var isLoading = false
    @State private var showCreateGroup = false
    @State private var showJoinGroup   = false
    @State private var showInviteCode  = false
    @State private var errorMessage: String?

    private var currentGroup: SubscriptionGroup? { appEnv.selectedGroup }

    var body: some View {
        NavigationStack {
            List {
                // グループ選択セクション
                if appEnv.groups.count > 1 {
                    Section("グループ切り替え") {
                        ForEach(appEnv.groups) { group in
                            Button {
                                Task {
                                    appEnv.selectedGroup = group
                                    await loadMembers()
                                }
                            } label: {
                                HStack {
                                    Text(group.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if group.id == currentGroup?.id {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }

                // 現在のグループ情報
                if let group = currentGroup {
                    Section("グループ情報") {
                        LabeledContent("グループ名", value: group.name)

                        // 招待コード（オーナーのみ表示）
                        if members.first(where: {
                            $0.userID == appEnv.currentUser?.id
                        })?.role == .owner {
                            Button {
                                showInviteCode = true
                            } label: {
                                Label("招待コードを確認", systemImage: "qrcode")
                            }
                        }
                    }

                    // メンバー一覧
                    Section("メンバー（\(members.count)人）") {
                        if members.isEmpty {
                            if isLoading {
                                ProgressView().frame(maxWidth: .infinity)
                            }
                        } else {
                            ForEach(members) { member in
                                MemberRow(
                                    member: member,
                                    isCurrentUser: member.userID == appEnv.currentUser?.id,
                                    isOwner: members.first(where: {
                                        $0.userID == appEnv.currentUser?.id
                                    })?.role == .owner,
                                    onRemove: {
                                        Task { await removeMember(member) }
                                    }
                                )
                            }
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("ファミリー")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showCreateGroup = true } label: {
                            Label("新しいグループを作成", systemImage: "plus")
                        }
                        Button { showJoinGroup = true } label: {
                            Label("招待コードで参加", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable { await loadMembers() }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupSheet()
                    .onDisappear { Task { await loadMembers() } }
            }
            .sheet(isPresented: $showJoinGroup) {
                JoinGroupSheet()
                    .onDisappear { Task { await loadMembers() } }
            }
            .sheet(isPresented: $showInviteCode) {
                if let group = currentGroup {
                    InviteCodeSheet(group: group)
                }
            }
        }
        .task { await loadMembers() }
    }

    private func loadMembers() async {
        guard let group = currentGroup else { return }
        isLoading = true
        defer { isLoading = false }
        members = (try? await appEnv.groupRepository.fetchMembers(groupID: group.id)) ?? []
    }

    private func removeMember(_ member: GroupMember) async {
        guard let group = currentGroup else { return }
        do {
            try await appEnv.groupRepository.removeMember(groupID: group.id, userID: member.userID)
            members.removeAll { $0.userID == member.userID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Member Row

private struct MemberRow: View {
    let member: GroupMember
    let isCurrentUser: Bool
    let isOwner: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .foregroundStyle(.secondary)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(isCurrentUser ? "自分" : "メンバー")
                        .font(.body)
                    if isCurrentUser {
                        Text("（あなた）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(member.role.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // オーナーは自分以外を削除可能
            if isOwner && !isCurrentUser {
                Button(role: .destructive) { onRemove() } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Invite Code Sheet

private struct InviteCodeSheet: View {
    let group: SubscriptionGroup
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(\.dismiss) private var dismiss
    @State private var isRegenerating = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                VStack(spacing: 12) {
                    Text("招待コード")
                        .font(.headline)
                    Text(group.inviteCode)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .padding()
                        .background(.tint.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        UIPasteboard.general.string = group.inviteCode
                    } label: {
                        Label("コードをコピー", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }

                Text("このコードを家族に共有してください。\nグループに参加できるのは招待コードを知っている人のみです。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                Button(role: .destructive) {
                    Task { await regenerate() }
                } label: {
                    if isRegenerating {
                        ProgressView()
                    } else {
                        Text("招待コードを再生成する")
                    }
                }
                .font(.footnote)
                .padding(.bottom, 32)
            }
            .padding()
            .navigationTitle("招待コード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func regenerate() async {
        isRegenerating = true
        defer { isRegenerating = false }
        _ = try? await appEnv.groupRepository.regenerateInviteCode(groupID: group.id)
        // グループ一覧を再読み込みして新しい招待コードを反映
        if let userID = appEnv.currentUser?.id {
            await appEnv.loadGroups(for: userID)
        }
    }
}
