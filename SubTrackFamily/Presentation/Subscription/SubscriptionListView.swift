import SwiftUI

struct SubscriptionListView: View {

    @Environment(AppEnvironment.self) private var appEnv
    @State private var viewModel: SubscriptionViewModel?
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    content(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("サブスク一覧")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityIdentifier("btn_addSubscription")
                }
            }
            .sheet(isPresented: $showAdd) {
                SubscriptionFormView(mode: .add)
                    .onDisappear { Task { await viewModel?.load() } }
            }
        }
        .task {
            guard let group = appEnv.selectedGroup else { return }
            let vm = SubscriptionViewModel(useCase: appEnv.subscriptionUseCase, groupID: group.id)
            viewModel = vm
            await vm.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionsDidChange)) { _ in
            Task { await viewModel?.load() }
        }
    }

    @ViewBuilder
    private func content(vm: SubscriptionViewModel) -> some View {
        @Bindable var vm = vm
        List {
            Picker("ステータス", selection: $vm.selectedStatus) {
                Text("すべて").tag(Subscription.Status?.none)
                ForEach(Subscription.Status.allCases, id: \.self) { s in
                    Text(s.displayName).tag(Subscription.Status?.some(s))
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            if vm.filtered.isEmpty {
                ContentUnavailableView(
                    "サブスクがありません",
                    systemImage: "creditcard",
                    description: Text("右上の ＋ ボタンから追加してください")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(vm.filtered) { sub in
                    NavigationLink {
                        SubscriptionDetailView(subscription: sub)
                    } label: {
                        SubscriptionRow(subscription: sub)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        Task { await vm.delete(vm.filtered[index]) }
                    }
                }
            }
        }
        .searchable(text: $vm.searchText, prompt: "サービス名で検索")
        .refreshable { await vm.load() }
    }
}

// MARK: - Row

private struct SubscriptionRow: View {
    let subscription: Subscription

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard.fill")
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(.tint.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(subscription.name).font(.body)
                    if subscription.isImportant {
                        Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                    }
                }
                Text(subscription.nextBillingDate.billingDaysLabel)
                    .font(.caption)
                    .foregroundStyle(subscription.nextBillingDate.isUpcomingBilling ? .orange : .secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.string(amount: subscription.amount, currencyCode: subscription.currency))
                    .font(.callout.bold())
                Text(subscription.billingCycle.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
