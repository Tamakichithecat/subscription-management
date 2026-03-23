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
            .navigationTitle("ホーム")
        }
        .task {
            guard let groupID = appEnv.currentUser?.id else { return }
            let vm = DashboardViewModel(
                subscriptionUseCase: appEnv.subscriptionUseCase,
                currencyUseCase: appEnv.currencyUseCase,
                groupID: groupID,
                baseCurrency: appEnv.currentUser?.baseCurrency ?? "JPY"
            )
            viewModel = vm
            await vm.load()
        }
    }

    @ViewBuilder
    private func content(vm: DashboardViewModel) -> some View {
        List {
            // 月次・年次サマリー
            Section {
                HStack {
                    VStack(alignment: .leading) {
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
                    VStack(alignment: .trailing) {
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
                Section("カテゴリー別") {
                    Chart(Array(vm.totalByCategory), id: \.key) { item in
                        SectorMark(
                            angle: .value("金額", item.value),
                            innerRadius: .ratio(0.6)
                        )
                        .foregroundStyle(by: .value("カテゴリー", item.key?.uuidString ?? "その他"))
                    }
                    .frame(height: 200)
                }
            }

            // 更新予定
            if !vm.upcomingBillings.isEmpty {
                Section("7日以内の更新") {
                    ForEach(vm.upcomingBillings) { sub in
                        UpcomingBillingRow(subscription: sub)
                    }
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
            if vm.isLoading { ProgressView() }
        }
    }
}

// MARK: - Sub Views

private struct UpcomingBillingRow: View {
    let subscription: Subscription

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.body)
                Text(subscription.nextBillingDate.billingDaysLabel)
                    .font(.caption)
                    .foregroundStyle(
                        subscription.nextBillingDate.isBillingToday ? .red : .secondary
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
