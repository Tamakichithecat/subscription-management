import SwiftUI
import Charts

struct DashboardView: View {

    @Environment(AppEnvironment.self) private var appEnv
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    content(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(appEnv.selectedGroup?.name ?? "ホーム")
            .toolbar { groupSwitcherButton }
        }
        .task { await setupViewModel() }
        // Realtimeからの変更通知を受けて再取得
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionsDidChange)) { _ in
            Task { await viewModel?.load() }
        }
    }

    // MARK: - Setup

    private func setupViewModel() async {
        guard let group = appEnv.selectedGroup else { return }
        let baseCurrency = appEnv.currentUser?.baseCurrency ?? "JPY"

        let vm = DashboardViewModel(
            subscriptionUseCase: appEnv.subscriptionUseCase,
            currencyUseCase: appEnv.currencyUseCase,
            groupID: group.id,
            baseCurrency: baseCurrency
        )
        viewModel = vm
        await vm.load()
    }

    // MARK: - Content

    @ViewBuilder
    private func content(vm: DashboardViewModel) -> some View {
        List {
            // 月次・年次サマリーカード
            Section {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今月の総支出")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.string(
                            amount: vm.monthlyTotal,
                            currencyCode: appEnv.currentUser?.baseCurrency ?? "JPY"
                        ))
                        .font(.title2.bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("年間換算")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.string(
                            amount: vm.annualTotal,
                            currencyCode: appEnv.currentUser?.baseCurrency ?? "JPY"
                        ))
                        .font(.headline)
                    }
                }
                .padding(.vertical, 4)
            }

            // カテゴリー別グラフ
            if !vm.totalByCategory.isEmpty {
                Section("カテゴリー別内訳") {
                    Chart(Array(vm.totalByCategory), id: \.key) { item in
                        SectorMark(
                            angle: .value("金額", item.value),
                            innerRadius: .ratio(0.6)
                        )
                        .foregroundStyle(by: .value("カテゴリー", item.key?.uuidString ?? "その他"))
                    }
                    .frame(height: 200)
                    .padding(.vertical, 4)
                }
            }

            // 更新予定
            if !vm.upcomingBillings.isEmpty {
                Section("7日以内の更新予定") {
                    ForEach(vm.upcomingBillings) { sub in
                        UpcomingBillingRow(subscription: sub)
                    }
                }
            } else {
                Section {
                    Label("直近7日以内の更新予定はありません", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }

            // アクティブ件数
            Section {
                Label("\(vm.activeCount) 件のサブスク契約中", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .refreshable { await vm.load() }
        .overlay {
            if vm.isLoading && vm.subscriptions.isEmpty {
                ProgressView()
            }
        }
    }

    // MARK: - Group Switcher

    @ToolbarContentBuilder
    private var groupSwitcherButton: some ToolbarContent {
        if appEnv.groups.count > 1 {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(appEnv.groups) { group in
                        Button {
                            Task {
                                appEnv.selectedGroup = group
                                await setupViewModel()
                            }
                        } label: {
                            if group.id == appEnv.selectedGroup?.id {
                                Label(group.name, systemImage: "checkmark")
                            } else {
                                Text(group.name)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
        }
    }
}

// MARK: - Upcoming Billing Row

private struct UpcomingBillingRow: View {
    let subscription: Subscription

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name).font(.body)
                Text(subscription.nextBillingDate.billingDaysLabel)
                    .font(.caption)
                    .foregroundStyle(
                        subscription.nextBillingDate.isBillingToday ? .red : .orange
                    )
            }
            Spacer()
            Text(CurrencyFormatter.string(
                amount: subscription.amount,
                currencyCode: subscription.currency
            ))
            .font(.callout.bold())
        }
    }
}
