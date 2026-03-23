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
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                SubscriptionFormView(mode: .add)
            }
        }
        .task {
            guard let groupID = appEnv.currentUser?.id else { return }
            let vm = SubscriptionViewModel(
                useCase: appEnv.subscriptionUseCase,
                groupID: groupID
            )
            viewModel = vm
            await vm.load()
        }
    }

    @ViewBuilder
    private func content(vm: SubscriptionViewModel) -> some View {
        @Bindable var vm = vm
        List {
            // ステータスフィルター
            Picker("ステータス", selection: $vm.selectedStatus) {
                Text("すべて").tag(Subscription.Status?.none)
                ForEach(Subscription.Status.allCases, id: \.self) { s in
                    Text(s.displayName).tag(Subscription.Status?.some(s))
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            ForEach(vm.filtered) { sub in
                NavigationLink {
                    SubscriptionDetailView(subscription: sub)
                } label: {
                    SubscriptionRow(subscription: sub)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let sub = vm.filtered[index]
                    Task { await vm.delete(sub) }
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
                    Text(subscription.name)
                        .font(.body)
                    if subscription.isImportant {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }
                Text(subscription.nextBillingDate.billingDaysLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.string(
                    amount: subscription.amount,
                    currencyCode: subscription.currency
                ))
                .font(.callout.bold())
                Text(subscription.billingCycle.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
