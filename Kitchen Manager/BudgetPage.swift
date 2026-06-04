import SwiftUI

struct BudgetPage: View {
    @Environment(KitchenStore.self) private var store

    @State private var form = BudgetEntryForm()
    @State private var selectedMonth = DateHelper.monthKey(for: Date())
    @State private var editingPurchaseRecord: PurchaseRecord?
    @State private var editingTransaction: BudgetTransaction?
    @State private var showingBudgetEditor = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case amount
        case note
    }

    private var availableMonths: [String] {
        let transactionMonths = store.budgetState.transactions.compactMap { tx -> String? in
            guard let date = DateHelper.date(from: tx.date) else { return nil }
            return DateHelper.monthKey(for: date)
        }
        let wasteMonths = store.budgetState.wasteRecords.compactMap { record -> String? in
            guard let date = DateHelper.date(from: record.date) else { return nil }
            return DateHelper.monthKey(for: date)
        }
        let purchaseMonths = store.budgetState.purchaseRecords.compactMap { record -> String? in
            guard let date = DateHelper.date(from: record.date) else { return nil }
            return DateHelper.monthKey(for: date)
        }
        var keys = Array(Set(transactionMonths + wasteMonths + purchaseMonths))
        let currentMonth = DateHelper.monthKey(for: Date())
        if !keys.contains(currentMonth) { keys.append(currentMonth) }
        return keys.sorted(by: >)
    }

    private var currentMonthTransactions: [BudgetTransaction] {
        store.budgetState.transactions.filter {
            guard let date = DateHelper.date(from: $0.date) else { return false }
            return DateHelper.monthKey(for: date) == selectedMonth
        }
    }

    private var currentMonthPurchaseRecords: [PurchaseRecord] {
        store.budgetState.purchaseRecords
            .filter {
                guard let date = DateHelper.date(from: $0.date) else { return false }
                return DateHelper.monthKey(for: date) == selectedMonth
            }
            .sorted { ($0.date, $0.id.uuidString) > ($1.date, $1.id.uuidString) }
    }

    private var linkedPurchaseTransactionIDs: Set<UUID> {
        Set(currentMonthPurchaseRecords.map(\.id))
    }

    private var currentMonthOtherTransactions: [BudgetTransaction] {
        currentMonthTransactions
            .filter { !linkedPurchaseTransactionIDs.contains($0.id) }
            .sorted { ($0.date, $0.id.uuidString) > ($1.date, $1.id.uuidString) }
    }

    private var currentMonthWasteRecords: [WasteRecord] {
        store.budgetState.wasteRecords
            .filter {
                guard let date = DateHelper.date(from: $0.date) else { return false }
                return DateHelper.monthKey(for: date) == selectedMonth
            }
            .sorted { ($0.date, $0.id.uuidString) > ($1.date, $1.id.uuidString) }
    }

    private var currentMonthSpent: Double {
        store.monthSpent(for: selectedMonth)
    }

    private var currentMonthWaste: Double {
        currentMonthWasteRecords.reduce(0) { $0 + $1.amount }
    }

    private var pendingShoppingEstimate: Double {
        guard selectedMonth == DateHelper.monthKey(for: Date()) else { return 0 }
        return store.pendingShoppingEstimate
    }

    private var projectedRemaining: Double {
        store.budgetState.monthlyBudget - currentMonthSpent - pendingShoppingEstimate
    }

    private var selectedMonthText: String {
        let parts = selectedMonth.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]) else { return selectedMonth }
        return "\(parts[0])年\(month)月"
    }

    private var budgetUseText: String {
        guard store.budgetState.monthlyBudget > 0 else { return "未设置" }
        let rate = currentMonthSpent / store.budgetState.monthlyBudget
        return "\(Int((rate * 100).rounded()))%"
    }

    private var headerMessage: String {
        if projectedRemaining < 0 {
            return "本月会超出预算，先看看待购预估和浪费记录。"
        }
        if pendingShoppingEstimate > 0 {
            return "预算仍有余量，待购清单已经计入预计支出。"
        }
        if currentMonthSpent == 0 {
            return "这个月还没有记录支出，可以从补记实付开始。"
        }
        return "厨房成本保持在预算内，继续按当前节奏记录。"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    KitchenPageHeader(
                        eyebrow: selectedMonthText,
                        title: projectedRemaining >= 0 ? "预计可用 \(projectedRemaining.currencyText)" : "预计超支 \(abs(projectedRemaining).currencyText)",
                        message: headerMessage,
                        symbol: "banknote.fill",
                        accent: projectedRemaining >= 0 ? KitchenTheme.brandGold : KitchenTheme.danger,
                        metrics: [
                            KitchenMetric(title: "预算上限", value: store.budgetState.monthlyBudget.currencyText, symbol: "gauge.with.dots.needle.33percent", accent: KitchenTheme.brandGold),
                            KitchenMetric(title: "已支出", value: currentMonthSpent.currencyText, symbol: "cart.fill", accent: KitchenTheme.brandGold),
                            KitchenMetric(title: "使用率", value: budgetUseText, symbol: projectedRemaining >= 0 ? "chart.pie.fill" : "exclamationmark.triangle.fill", accent: projectedRemaining >= 0 ? KitchenTheme.brandGold : KitchenTheme.danger)
                        ],
                        actionTitle: "设置预算上限",
                        actionSymbol: "slider.horizontal.3",
                        action: { showingBudgetEditor = true }
                    )
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("补记实付")
                            .font(.headline)

                        HStack(spacing: 10) {
                            TextField("金额", text: $form.amount)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .amount)

                            Picker("分类", selection: $form.category) {
                                ForEach(KitchenData.budgetCategories, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                        }

                        TextField("备注（可选）", text: $form.note)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .note)
                            .submitLabel(.done)

                        FilledButton(title: "记录支出") { addTransaction() }
                    }
                    .cardStyle()
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("采购记录")
                                .font(.headline)
                            Spacer()
                            Text("共 \(currentMonthPurchaseRecords.count) 次")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if currentMonthPurchaseRecords.isEmpty {
                            Text("本月还没有采购记录。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(currentMonthPurchaseRecords) { record in
                                PurchaseRecordRow(record: record)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingPurchaseRecord = record }
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("其他支出")
                                .font(.headline)
                            Spacer()
                            Text("共 \(currentMonthOtherTransactions.count) 笔")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if currentMonthOtherTransactions.isEmpty {
                            Text("本月暂无其他支出。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(currentMonthOtherTransactions) { tx in
                                OtherExpenseRow(transaction: tx)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingTransaction = tx }
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("浪费记录")
                                .font(.headline)
                            Spacer()
                            Text("共 \(currentMonthWasteRecords.count) 笔")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if currentMonthWasteRecords.isEmpty {
                            Text("本月暂无浪费记录。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(currentMonthWasteRecords) { record in
                                WasteRecordRow(record: record)
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded {
                    focusedField = nil
                }
            )
            .background(KitchenTheme.background)
            .navigationTitle(selectedMonth == DateHelper.monthKey(for: Date()) ? "厨房账本" : "\(selectedMonth) 成本")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(availableMonths, id: \.self) { month in
                            Button(month) { selectedMonth = month }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingBudgetEditor = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                }
            }
            .sheet(item: $editingPurchaseRecord) { record in
                PurchaseRecordEditSheet(
                    record: record,
                    onSave: { updated in
                        let didSave = store.updatePurchaseRecord(updated)
                        if didSave {
                            store.showToast("已更新采购记录并同步库存")
                        }
                        return didSave
                    },
                    onDelete: {
                        store.deletePurchaseRecord(record)
                        store.showToast("已删除采购记录并回退库存")
                    }
                )
            }
            .sheet(item: $editingTransaction) { tx in
                BudgetEditSheet(
                    transaction: tx,
                    onSave: { updated in
                        guard let index = store.budgetState.transactions.firstIndex(where: { $0.id == updated.id }) else { return }
                        store.budgetState.transactions[index] = updated
                        store.showToast("已更新支出记录")
                    },
                    onDelete: {
                        store.budgetState.transactions.removeAll { $0.id == tx.id }
                        store.showToast("已删除记录")
                    }
                )
            }
            .sheet(isPresented: $showingBudgetEditor) {
                BudgetLimitSheet(
                    currentBudget: store.budgetState.monthlyBudget,
                    onSave: { newBudget in
                        store.budgetState.monthlyBudget = newBudget
                        store.showToast("已更新月预算上限")
                    }
                )
            }
        }
    }

    private func addTransaction() {
        guard let amount = Double(form.amount), amount > 0 else { return }
        let tx = BudgetTransaction(
            amount: amount,
            note: form.note.trimmingCharacters(in: .whitespacesAndNewlines),
            category: form.category,
            date: DateHelper.todayKey
        )
        store.budgetState.transactions.append(tx)
        focusedField = nil
        form.amount = ""
        form.note = ""
        store.showToast("已记录支出 \(amount.currencyText)")
    }
}

private struct PurchaseRecordRow: View {
    let record: PurchaseRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "basket.fill")
                    .foregroundStyle(KitchenTheme.brandCrimson)
                    .frame(width: 34, height: 34)
                    .background(KitchenTheme.brandCrimson.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(record.summaryText)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text("\(record.date) · \(record.itemCount) 项")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(record.totalAmount.currencyText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }

            if !record.items.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(record.items.prefix(4))) { item in
                        Text("\(item.name) \(item.quantity)\(item.unit)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                    if record.items.count > 4 {
                        Text("+\(record.items.count - 4)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct OtherExpenseRow: View {
    let transaction: BudgetTransaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "banknote")
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color(.tertiarySystemFill), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(transaction.category)
                        .font(.subheadline.weight(.medium))
                    if !transaction.note.isEmpty {
                        Text(transaction.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Text(transaction.date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(transaction.amount.currencyText)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .padding(.vertical, 4)
    }
}

private struct WasteRecordRow: View {
    let record: WasteRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .foregroundStyle(.red)
                .frame(width: 32, height: 32)
                .background(KitchenTheme.danger.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(record.itemName)
                    .font(.subheadline.weight(.medium))
                Text(record.date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(record.amount.currencyText)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.red)
        }
        .padding(.vertical, 4)
    }
}

struct PurchaseRecordEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let record: PurchaseRecord
    let onSave: (PurchaseRecord) -> Bool
    let onDelete: () -> Void

    @State private var date: Date
    @State private var lineItems: [PurchaseLineItem]
    @State private var errorMessage = ""

    init(record: PurchaseRecord, onSave: @escaping (PurchaseRecord) -> Bool, onDelete: @escaping () -> Void) {
        self.record = record
        self.onSave = onSave
        self.onDelete = onDelete
        _date = State(initialValue: DateHelper.date(from: record.date) ?? Date())
        _lineItems = State(initialValue: record.items)
    }

    private var totalAmount: Double {
        lineItems.reduce(0) { $0 + $1.totalCost }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("保存后会同步更新库存数量和本次采购金额。")) {
                    DatePicker("采购日期", selection: $date, displayedComponents: .date)
                }

                Section("采购明细") {
                    ForEach($lineItems) { $item in
                        PurchaseLineItemEditor(item: $item)
                    }
                    .onDelete { offsets in
                        lineItems.remove(atOffsets: offsets)
                    }

                    Button {
                        lineItems.append(
                            PurchaseLineItem(
                                name: "",
                                quantity: "1",
                                unit: "个",
                                unitPrice: 0,
                                category: "其他"
                            )
                        )
                    } label: {
                        Label("新增项目", systemImage: "plus.circle.fill")
                    }
                }

                Section {
                    HStack {
                        Text("合计")
                        Spacer()
                        Text(totalAmount.currencyText)
                            .font(.headline.monospacedDigit())
                    }
                }

                Section {
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button("保存修改") {
                        let updated = PurchaseRecord(
                            id: record.id,
                            date: DateHelper.key(for: date),
                            totalAmount: totalAmount,
                            items: lineItems
                        )
                        if onSave(updated) {
                            dismiss()
                        } else {
                            errorMessage = "请至少保留一条有效的采购项目。"
                        }
                    }
                    .fontWeight(.semibold)

                    Button("删除本次采购", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle("编辑采购记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct PurchaseLineItemEditor: View {
    @Binding var item: PurchaseLineItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("项目名称", text: $item.name)

            HStack(spacing: 12) {
                TextField("数量", text: $item.quantity)
                    .keyboardType(.decimalPad)

                TextField("单位", text: $item.unit)
                    .textInputAutocapitalization(.never)
            }

            Picker("分类", selection: $item.category) {
                ForEach(KitchenData.categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }

            HStack {
                Text("单价 (€)")
                Spacer()
                TextField("0.00", value: $item.unitPrice, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }

            HStack {
                Spacer()
                Text("小计 \(item.totalCost.currencyText)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct BudgetEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let transaction: BudgetTransaction
    let onSave: (BudgetTransaction) -> Void
    let onDelete: () -> Void

    @State private var amount: String
    @State private var category: String
    @State private var note: String
    @State private var date: Date

    init(transaction: BudgetTransaction, onSave: @escaping (BudgetTransaction) -> Void, onDelete: @escaping () -> Void) {
        self.transaction = transaction
        self.onSave = onSave
        self.onDelete = onDelete
        _amount = State(initialValue: transaction.amount.cleanString)
        _category = State(initialValue: transaction.category)
        _note = State(initialValue: transaction.note)
        _date = State(initialValue: DateHelper.date(from: transaction.date) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("金额")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("分类", selection: $category) {
                        ForEach(KitchenData.budgetCategories, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("备注", text: $note)
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }

                Section {
                    Button("保存修改") {
                        guard let amt = Double(amount), amt > 0 else { return }
                        onSave(BudgetTransaction(
                            id: transaction.id,
                            amount: amt,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category,
                            date: DateHelper.key(for: date)
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)

                    Button("删除记录", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle("编辑支出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct BudgetLimitSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentBudget: Double
    let onSave: (Double) -> Void

    @State private var amount: String

    init(currentBudget: Double, onSave: @escaping (Double) -> Void) {
        self.currentBudget = currentBudget
        self.onSave = onSave
        _amount = State(initialValue: currentBudget.cleanString)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("用于计算本月预算余量。")) {
                    HStack {
                        Text("预算金额 (€)")
                        Spacer()
                        TextField("300", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Button("保存") {
                        guard let newBudget = Double(amount), newBudget > 0 else { return }
                        onSave(newBudget)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationTitle("设置月预算上限")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
