import SwiftUI

struct SubscriptionFormView: View {

    enum Mode {
        case add
        case edit(Subscription)
    }

    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var appEnv

    // フォームの状態
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var currency: String = "JPY"
    @State private var billingCycle: Subscription.BillingCycle = .monthly
    @State private var nextBillingDate: Date = Date()
    @State private var status: Subscription.Status = .active
    @State private var paymentMethodNote: String = ""
    @State private var isImportant: Bool = false
    @State private var autoRenew: Bool = true
    @State private var notes: String = ""
    @State private var serviceURL: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("サービス名", text: $name)
                    Picker("ステータス", selection: $status) {
                        ForEach(Subscription.Status.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    TextField("サービスURL", text: $serviceURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("請求情報") {
                    HStack {
                        TextField("金額", text: $amount)
                            .keyboardType(.decimalPad)
                        Picker("通貨", selection: $currency) {
                            ForEach(AppConstants.SupportedCurrencies.all, id: \.self) { c in
                                Text(c).tag(c)
                            }
                        }
                        .frame(width: 90)
                    }
                    Picker("請求サイクル", selection: $billingCycle) {
                        ForEach(Subscription.BillingCycle.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    DatePicker("次回請求日", selection: $nextBillingDate, displayedComponents: .date)
                    Toggle("自動更新", isOn: $autoRenew)
                }

                Section("契約情報") {
                    TextField("支払い方法メモ（例: JCBカード末尾1234）", text: $paymentMethodNote)
                    Toggle("重要フラグ", isOn: $isImportant)
                }

                Section("メモ") {
                    TextField("自由記入", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditMode ? "サブスクを編集" : "サブスクを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditMode ? "保存" : "追加") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || amount.isEmpty || isLoading)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        guard case .edit(let sub) = mode else { return }
        name = sub.name
        amount = "\(sub.amount)"
        currency = sub.currency
        billingCycle = sub.billingCycle
        nextBillingDate = sub.nextBillingDate
        status = sub.status
        paymentMethodNote = sub.paymentMethodNote ?? ""
        isImportant = sub.isImportant
        autoRenew = sub.autoRenew
        notes = sub.notes ?? ""
        serviceURL = sub.serviceURL ?? ""
    }

    private func save() async {
        guard let amountDecimal = Decimal(string: amount) else {
            errorMessage = "金額の形式が正しくありません"
            return
        }
        guard let groupID = appEnv.selectedGroup?.id else {
            errorMessage = "グループが選択されていません"
            return
        }

        isLoading = true
        defer { isLoading = false }

        let sub = Subscription(
            id: { if case .edit(let s) = mode { return s.id } else { return UUID() } }(),
            groupID: groupID,
            name: name,
            description: nil,
            categoryID: nil,
            status: status,
            serviceURL: serviceURL.isEmpty ? nil : serviceURL,
            contractorUserID: appEnv.currentUser?.id,
            paymentMethodNote: paymentMethodNote.isEmpty ? nil : paymentMethodNote,
            isImportant: isImportant,
            amount: amountDecimal,
            currency: currency,
            billingCycle: billingCycle,
            billingCycleDays: nil,
            startDate: nil,
            nextBillingDate: nextBillingDate,
            endDate: nil,
            autoRenew: autoRenew,
            notes: notes.isEmpty ? nil : notes,
            createdBy: appEnv.currentUser?.id,
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            if case .edit = mode {
                _ = try await appEnv.subscriptionUseCase.update(sub)
            } else {
                _ = try await appEnv.subscriptionUseCase.create(sub)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
