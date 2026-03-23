import SwiftUI

/// 相続対応：契約者・支払い方法を一覧で確認できる画面
struct ContractListView: View {

    @Environment(AppEnvironment.self) private var appEnv
    @State private var subscriptions: [Subscription] = []
    @State private var isLoading = false
    @State private var showImportantOnly = false

    private var displayed: [Subscription] {
        showImportantOnly
            ? subscriptions.filter { $0.isImportant && $0.status.isActive }
            : subscriptions.filter { $0.status.isActive }
    }

    var body: some View {
        NavigationStack {
            List {
                Toggle("重要のみ表示", isOn: $showImportantOnly)
                    .listRowBackground(Color.clear)

                ForEach(displayed) { sub in
                    ContractRow(subscription: sub)
                }
            }
            .navigationTitle("契約情報一覧")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    // TODO: PDFエクスポート（v1.2）
                }
            }
            .overlay { if isLoading { ProgressView() } }
        }
        .task {
            guard let groupID = appEnv.currentUser?.id else { return }
            isLoading = true
            defer { isLoading = false }
            subscriptions = (try? await appEnv.subscriptionUseCase.fetchAll(groupID: groupID)) ?? []
        }
    }
}

private struct ContractRow: View {
    let subscription: Subscription

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(subscription.name)
                    .font(.headline)
                if subscription.isImportant {
                    Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                }
                Spacer()
                Text(subscription.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.1))
                    .clipShape(Capsule())
            }
            if let note = subscription.paymentMethodNote {
                Label(note, systemImage: "creditcard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(CurrencyFormatter.string(
                    amount: subscription.amount,
                    currencyCode: subscription.currency
                ))
                .font(.caption.bold())
                Text("/ \(subscription.billingCycle.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
