import SwiftUI

struct ShoppingPage: View {
    @Environment(KitchenStore.self) private var store

    @State private var form = ShoppingItemForm()
    @State private var selectedCategory = "全部"
    @State private var showingAddForm = false
    @State private var showingFixedDays = false
    @State private var showingSchedule = false
    @State private var showingCheckout = false

    private var currentWeekDates: [Date] {
        DateHelper.weekDates(from: DateHelper.weekStart(for: Date()))
    }

    private var resolvedDays: [String] {
        store.shoppingState.resolvedShopDays(for: currentWeekDates)
    }

    private var completedCount: Int {
        store.shoppingState.items.filter { $0.isChecked }.count
    }

    private var checkedItems: [ShoppingItem] {
        store.shoppingState.items.filter { $0.isChecked }
    }

    private var checkedEstimatedTotal: Double {
        checkedItems.reduce(0) { $0 + $1.estimatedTotalCost }
    }

    private var itemGroups: [ShoppingDayGroup] {
        store.shoppingState.itemGroups(category: selectedCategory)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("\(store.shoppingState.items.count) 项").font(.headline)
                        Spacer()
                        Text("预估 \(store.pendingShoppingEstimate.currencyText)")
                            .monospacedDigit()
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(["全部"] + KitchenData.categories, id: \.self) { category in
                                KitchenChip(title: category,
                                            style: selectedCategory == category ? .filled : .tinted,
                                            isSelected: selectedCategory == category) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }

                    if itemGroups.isEmpty {
                        EmptyStateCard(symbol: "cart", title: "暂无采购项", subtitle: "")
                    } else {
                        ForEach(itemGroups) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(group.title()).font(.headline)
                                        .accessibilityAddTraits(.isHeader)
                                    Spacer()
                                    if group.day.isEmpty {
                                        Button("分配到今天") { assignVisibleUnassigned() }
                                            .font(.caption)
                                            .frame(minHeight: 44)
                                    }
                                }
                                VStack(spacing: 0) {
                                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                        ShoppingItemRow(item: item, onToggle: { toggleItem(item) },
                                                        onDelete: { deleteItem(item) },
                                                        shopDays: Array(Set(resolvedDays + [DateHelper.todayKey, item.day])).filter { !$0.isEmpty }.sorted(),
                                                        onAssign: { assignItemToDay(item, day: $0) })
                                        if index < group.items.count - 1 { Divider() }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .background(KitchenTheme.surface, in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.md))
                            }
                        }
                    }
                }
                .padding()
            }
            .background(KitchenTheme.background)
            .safeAreaInset(edge: .bottom, spacing: 0) { checkoutBottomBar }
            .navigationTitle("购物清单")
            .animation(.snappy(duration: 0.22), value: completedCount)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSchedule = true } label: { Image(systemName: "calendar") }
                        .accessibilityLabel("购物日")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddForm = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("添加采购项")
                }
            }
            .sheet(isPresented: $showingAddForm) {
                AddShoppingItemSheet(form: $form, shopDays: Array(Set(resolvedDays + [DateHelper.todayKey, form.day])).filter { !$0.isEmpty }.sorted()) {
                    addManualShoppingItem()
                }
            }
            .sheet(isPresented: $showingSchedule) {
                NavigationStack {
                    Form {
                        Section {
                            ForEach(currentWeekDates, id: \.self) { date in
                                let key = DateHelper.key(for: date)
                                Toggle("\(DateHelper.weekdayName(for: date)) \(DateHelper.monthDayString(date))", isOn: Binding(
                                    get: { resolvedDays.contains(key) },
                                    set: { _ in toggleShoppingDay(key) }
                                ))
                            }
                        }
                        Section { Button("每周重复…") { showingFixedDays = true } }
                    }
                    .navigationTitle("购物日")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showingSchedule = false }
                    } }
                    .sheet(isPresented: $showingFixedDays) { FixedShopDaysSheet() }
                }
            }
            .sheet(isPresented: $showingCheckout) { CheckoutSheet(checkedItems: checkedItems) }
        }
    }

    @ViewBuilder
    private var checkoutBottomBar: some View {
        if completedCount > 0 {
            VStack(spacing: 0) {
                Divider()

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已勾选 \(completedCount) 项")
                            .font(.subheadline.weight(.semibold))
                        Text("预估 \(checkedEstimatedTotal.currencyText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Button {
                        clearCheckedItems()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.title3.weight(.medium))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("取消勾选")

                    Button {
                        showingCheckout = true
                    } label: {
                        Label("结算入库", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(minWidth: 108)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(KitchenTheme.brandCrimson)
                    .controlSize(.large)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    private func toggleShoppingDay(_ day: String) {
        if let date = DateHelper.date(from: day) {
            let weekday = Calendar.current.component(.weekday, from: date)
            let normalized = weekday == 1 ? 7 : weekday - 1
            if store.shoppingState.fixedShopWeekdays.contains(normalized) {
                showingFixedDays = true
                return
            }
        }
        if let index = store.shoppingState.shopDays.firstIndex(of: day) {
            store.shoppingState.shopDays.remove(at: index)
        } else {
            store.shoppingState.shopDays.append(day)
            store.shoppingState.shopDays.sort()
        }
    }

    private func addManualShoppingItem() {
        let trimmed = form.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        store.shoppingState.items.append(
            ShoppingItem(
                name: trimmed,
                quantity: form.quantity.isEmpty ? "1" : form.quantity,
                unit: form.unit,
                category: form.category,
                day: form.day,
                isChecked: false,
                estimatedUnitPrice: Double(form.estimatedUnitPrice)
            )
        )

        form.name = ""
        form.quantity = ""
        form.estimatedUnitPrice = ""
        store.showToast("\(trimmed),加进清单了。", kind: .success)
        showingAddForm = false
    }

    private func toggleItem(_ item: ShoppingItem) {
        guard let index = store.shoppingState.items.firstIndex(where: { $0.id == item.id }) else { return }
        store.shoppingState.items[index].isChecked.toggle()
    }

    private func deleteItem(_ item: ShoppingItem) {
        store.shoppingState.items.removeAll { $0.id == item.id }
        store.showToast("已移除 \(item.name)")
    }

    private func assignItemToDay(_ item: ShoppingItem, day: String) {
        guard let index = store.shoppingState.items.firstIndex(where: { $0.id == item.id }) else { return }
        store.shoppingState.items[index].day = day
        store.showToast("\(item.name) → \(day == DateHelper.todayKey ? "今天" : day)")
    }

    private func assignVisibleUnassigned() {
        for i in store.shoppingState.items.indices where store.shoppingState.items[i].day.isEmpty {
            if selectedCategory == "全部" || store.shoppingState.items[i].category == selectedCategory {
                store.shoppingState.items[i].day = DateHelper.todayKey
            }
        }
    }

    private func clearCheckedItems() {
        for index in store.shoppingState.items.indices {
            store.shoppingState.items[index].isChecked = false
        }
    }
}

// MARK: - Checkout Sheet

struct CheckoutSheet: View {
    @Environment(KitchenStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let checkedItems: [ShoppingItem]
    @State private var lineItems: [PurchaseLineItem] = []

    private var total: Double {
        lineItems.reduce(0) { $0 + $1.totalCost }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("确认采购明细"), footer: Text("确认后自动入库并记账。")) {
                    ForEach($lineItems) { $item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))

                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Text("数量")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("", text: $item.quantity)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 60)
                                }

                                Text(item.unit)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                HStack(spacing: 4) {
                                    Text("单价 €")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("", value: $item.unitPrice, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 70)
                                }
                            }

                            HStack {
                                Spacer()
                                Text("小计 \(item.totalCost.currencyText)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        lineItems.remove(atOffsets: indexSet)
                    }
                }

                Section {
                    HStack {
                        Text("合计")
                            .font(.headline)
                        Spacer()
                        Text(total.currencyText)
                            .font(.headline.monospacedDigit())
                    }

                    Button("确认结算") {
                        guard store.checkoutShoppingTrip(lineItems: lineItems) else {
                            store.showToast("请至少保留一项有效的商品名称和数量。", kind: .error)
                            return
                        }
                        store.showToast("搞定,\(lineItems.count) 项进库,共支出 \(total.currencyText)。", kind: .success)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(lineItems.isEmpty)
                }
            }
            .navigationTitle("采购结算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            lineItems = checkedItems.map { item in
                PurchaseLineItem(
                    shoppingItemID: item.id,
                    name: item.name,
                    quantity: item.quantity.isEmpty ? "1" : item.quantity,
                    unit: item.unit,
                    unitPrice: item.effectiveUnitPrice,
                    category: item.category
                )
            }
        }
    }
}

// MARK: - Fixed Shop Days Sheet

struct FixedShopDaysSheet: View {
    @Environment(KitchenStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let weekdayNames = DateHelper.weekdayNames

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section(footer: Text("选中的日期每周自动添加。")) {
                    ForEach(1...7, id: \.self) { day in
                        let index = day - 1
                        Toggle(weekdayNames[index], isOn: Binding(
                            get: { store.shoppingState.fixedShopWeekdays.contains(day) },
                            set: { enabled in
                                if enabled {
                                    store.shoppingState.fixedShopWeekdays.insert(day)
                                } else {
                                    store.shoppingState.fixedShopWeekdays.remove(day)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("每周固定购物日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Add Shopping Item Sheet

private struct AddShoppingItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var form: ShoppingItemForm
    let shopDays: [String]
    let onAdd: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("名称", text: $form.name)
                        .onChange(of: form.name) { _, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard trimmed.count >= 2 else { return }
                            form.category = KitchenData.categoryGuess(for: trimmed)
                            form.unit = KitchenData.unitGuess(for: trimmed, category: form.category)
                        }
                    HStack {
                        TextField("数量", text: $form.quantity)
                            .keyboardType(.decimalPad)
                        Picker("单位", selection: $form.unit) {
                            ForEach(KitchenData.units, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Picker("分类", selection: $form.category) {
                        ForEach(KitchenData.categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }

                Section("其他") {
                    TextField("参考单价 (€)", text: $form.estimatedUnitPrice)
                        .keyboardType(.decimalPad)
                    Picker("分配到购物日", selection: $form.day) {
                        Text("不指定").tag("")
                        ForEach(shopDays, id: \.self) { day in
                            Text(day).tag(day)
                        }
                    }
                }

                Section {
                    Button("添加到清单") { onAdd() }
                        .fontWeight(.semibold)
                        .disabled(form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("手动添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
