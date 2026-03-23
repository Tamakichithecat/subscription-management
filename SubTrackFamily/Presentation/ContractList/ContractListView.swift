import SwiftUI

/// 相続対応：契約者・支払い方法を一覧で確認できる画面
struct ContractListView: View {

    @Environment(AppEnvironment.self) private var appEnv
    @State private var subscriptions: [Subscription] = []
    @State private var isLoading = false
    @State private var showImportantOnly = false

    private var displayed: [Subscription] {
        let active = subscriptions.filter { $0.status.isActive }
        return showImportantOnly ? active.filter { $0.isImportant } : active
    }

    var body: some View {
        NavigationStack {
            List {
                Toggle("重要フラグのみ表示", isOn: $showImportantOnly)
                    .listRowBackground(Color.clear)

                if displayed.isEmpty {
                    ContentUnavailableView(
                        showImportantOnly ? "重要なサブスクはありません" : "サブスクがありません",
                        systemImage: "doc.text.magnifyingglass"
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(displayed) { sub in
                        ContractRow(subscription: sub)
                    }
                }
            }
            .navigationTitle("契約情報一覧")
            .overlay { if isLoading { ProgressView() } }
            .refreshable { await load() }
        }
        .task { await load() }
    }

    private func load() async {
        guard let group = appEnv.selectedGroup else { return }
        isLoading = true
        defer { isLoading = false }
        subscriptions = (try? await appEnv.subscriptionUseCase.fetchAll(groupID: group.id)) ?? []
    }
}

// MARK: - Contract Row

private struct ContractRow: View {
    let subscription: Subscription

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(subscription.name).font(.headline)
                if subscription.isImportant {
                    Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                }
                Spacer()
                StatusBadge(status: subscription.status)
            }

            if let note = subscription.paymentMethodNote {
                Label(note, systemImage: "creditcard")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Label("支払い方法未設定", systemImage: "creditcard")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            HStack {
                Text(CurrencyFormatter.string(
                    amount: subscription.amount,
                    currencyCode: subscription.currency
                ))
                .font(.caption.bold())
                Text("/ \(subscription.billingCycle.displayName)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("次回: \(subscription.nextBillingDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let status: Subscription.Status

    var color: Color {
        switch status {
        case .active:    return .green
        case .trial:     return .blue
        case .inactive:  return .orange
        case .cancelled: return .gray
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
