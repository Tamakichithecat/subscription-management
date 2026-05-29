import SwiftUI
import Charts

struct ReportsView: View {

    @Environment(AppEnvironment.self) private var appEnv
    @State private var subscriptions: [Subscription] = []
    @State private var exchangeRates: [ExchangeRate] = []

    private var baseCurrency: String {
        appEnv.currentUser?.baseCurrency ?? "JPY"
    }

    private var categoryTotals: [(label: String, amount: Decimal)] {
        let grouped = Dictionary(grouping: subscriptions.filter { $0.status.isActive }, by: { $0.billingCycle })
        return grouped.map { cycle, subs in
            let total = subs.reduce(Decimal.zero) { $0 + $1.monthlyAmount }
            return (label: cycle.displayName, amount: total)
        }
        .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("月次支出内訳") {
                    if categoryTotals.isEmpty {
                        Text("データがありません")
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(categoryTotals, id: \.label) { item in
                            BarMark(
                                x: .value("サイクル", item.label),
                                y: .value("金額", item.amount)
                            )
                            .foregroundStyle(by: .value("サイクル", item.label))
                        }
                        .frame(height: 200)
                    }
                }

                Section("サブスク一覧（月換算）") {
                    ForEach(subscriptions.filter { $0.status.isActive }) { sub in
                        HStack {
                            Text(sub.name)
                            Spacer()
                            Text(CurrencyFormatter.string(
                                amount: sub.monthlyAmount,
                                currencyCode: sub.currency
                            ))
                            .font(.caption.bold())
                        }
                    }
                }
            }
            .navigationTitle("レポート")
        }
        .task {
            guard let groupID = appEnv.selectedGroup?.id else { return }
            subscriptions = (try? await appEnv.subscriptionUseCase.fetchAll(groupID: groupID)) ?? []
            exchangeRates = (try? await appEnv.currencyUseCase.fetchRates(base: baseCurrency)) ?? []
        }
    }
}
