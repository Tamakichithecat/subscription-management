import SwiftUI

struct SubscriptionDetailView: View {

    let subscription: Subscription
    @State private var showEdit = false

    var body: some View {
        List {
            Section("基本情報") {
                LabeledContent("サービス名", value: subscription.name)
                LabeledContent("ステータス", value: subscription.status.displayName)
                if let desc = subscription.description {
                    LabeledContent("説明", value: desc)
                }
            }

            Section("請求情報") {
                LabeledContent("金額") {
                    Text(CurrencyFormatter.string(
                        amount: subscription.amount,
                        currencyCode: subscription.currency
                    ))
                    .bold()
                }
                LabeledContent("請求サイクル", value: subscription.billingCycle.displayName)
                LabeledContent("次回請求日") {
                    VStack(alignment: .trailing) {
                        Text(subscription.nextBillingDate.formatted(date: .long, time: .omitted))
                        Text(subscription.nextBillingDate.billingDaysLabel)
                            .font(.caption)
                            .foregroundStyle(
                                subscription.nextBillingDate.isUpcomingBilling ? .orange : .secondary
                            )
                    }
                }
                LabeledContent("自動更新", value: subscription.autoRenew ? "あり" : "なし")
            }

            Section("契約情報") {
                if let note = subscription.paymentMethodNote {
                    LabeledContent("支払い方法", value: note)
                }
                if subscription.isImportant {
                    Label("重要フラグあり", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                }
                if let url = subscription.serviceURL, let link = URL(string: url) {
                    Link(destination: link) {
                        Label("サービスページを開く", systemImage: "safari")
                    }
                }
            }

            if let notes = subscription.notes {
                Section("メモ") {
                    Text(notes)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(subscription.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("編集") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            SubscriptionFormView(mode: .edit(subscription))
        }
    }
}
