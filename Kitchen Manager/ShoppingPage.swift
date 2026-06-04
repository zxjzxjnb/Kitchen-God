import SwiftUI

struct ShoppingPage: View {
    @Environment(KitchenStore.self) private var store

    @State private var form = ShoppingItemForm()
    @State private var selectedCategory = "全部"
    @State private var showingAddForm = false
    @State private var showingFixedDays = false
    @State private var showingCheckout = false

    private var currentWeekDates: [Date] {
        DateHelper.weekDates(from: DateHelper.weekStart(for: Date()))
    }

    private var resolvedDays: [String] {
        store.shoppingState.resolvedShopDays(for: currentWeekDates)
    }

    private var filteredItems: [ShoppingItem] {
        selectedCategory == "全部" ? store.shoppingState.items : store.shoppingState.items.filter { $0.category == selectedCategory }
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

    private var pendingItems: [ShoppingItem] {
        store.shoppingState.items.filter { !$0.isChecked }
    }

    private var pendingEstimatedTotal: Double {
        pendingItems.reduce(0) { $0 + $1.estimatedTotalCost }
    }

    private var projectedBudgetRemaining: Double {
        store.budgetState.monthlyBudget - store.currentMonthSpent - pendingEstimatedTotal
    }

    private var nearestShopDay: String {
        let today = DateHelper.todayKey
        return resolvedDays.first(where: { $0 >= today }) ?? resolvedDays.first ?? ""
    }

    private var nearestShopDayText: String {
        guard !nearestShopDay.isEmpty else { return "未设定" }
        if nearestShopDay == DateHelper.todayKey { return "今天" }
        guard let date = DateHelper.date(from: nearestShopDay) else { return nearestShopDay }
        return "\(DateHelper.weekdayName(for: date)) \(DateHelper.monthDayString(date))"
    }

    private var headerMessage: String {
        if pendingItems.isEmpty {
            return completedCount > 0 ? "采购清单已经处理完，可以直接结算入库。" : "采购清单已经清爽，暂时不用额外补货。"
        }
        if projectedBudgetRemaining < 0 {
            return "这批采购会让预算超出，优先删减非必要项。"
        }
        if resolvedDays.isEmpty {
            return "先选一个购物日，清单就能按日期分组处理。"
        }
        if nearestShopDay == DateHelper.todayKey {
            return "今天适合把清单带出门，未分配项目可以一键归到最近购物日。"
        }
        return "清单和预算都在可控范围，按购物日分批处理就好。"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    KitchenPageHeader(
                        eyebrow: "采购节奏",
                        title: pendingItems.isEmpty ? "清单已清爽" : "\(pendingItems.count) 项待采购",
                        message: headerMessage,
                        symbol: "cart.fill",
                        accent: projectedBudgetRemaining < 0 ? KitchenTheme.danger : KitchenTheme.brandGold,
                        metrics: [
                            KitchenMetric(title: "待购预估", value: pendingEstimatedTotal.currencyText, symbol: "eurosign.circle.fill", accent: KitchenTheme.brandGold),
                            KitchenMetric(title: "预算余量", value: projectedBudgetRemaining.currencyText, symbol: projectedBudgetRemaining >= 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill", accent: projectedBudgetRemaining >= 0 ? KitchenTheme.brandGold : KitchenTheme.danger),
                            KitchenMetric(title: "下次购物", value: nearestShopDayText, symbol: "calendar.badge.clock", accent: KitchenTheme.brandGold)
                        ],
                        actionTitle: "添加采购项",
                        actionSymbol: "plus.circle.fill",
                        action: { showingAddForm = true }
                    )
                    .padding(.horizontal)

                    // Shopping days
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("购物日")
                                .font(.headline)
                            Spacer()
                            Button { showingFixedDays = true } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "repeat")
                                    Text("固定")
                                }
                                .font(.caption.weight(.medium))
                            }
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                            ForEach(currentWeekDates, id: \.self) { date in
                                let dateKey = DateHelper.key(for: date)
                                let isSelected = resolvedDays.contains(dateKey)
                                DayChip(
                                    weekday: DateHelper.weekdayName(for: date),
                                    dayText: DateHelper.monthDayString(date),
                                    badgeCount: pendingCount(for: dateKey),
                                    isSelected: isSelected,
                                    isToday: dateKey == DateHelper.todayKey,
                                    accent: KitchenTheme.brandGold,
                                    minHeight: 44
                                ) {
                                    toggleShoppingDay(dateKey)
                                }
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)

                    // Category filter
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("分类筛选")
                                .font(.headline)
                            Spacer()
                            Text("\(filteredItems.count) 项")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(["全部"] + KitchenData.categories, id: \.self) { category in
                                    KitchenChip(
                                        title: category,
                                        style: selectedCategory == category ? .filled : .tinted,
                                        color: KitchenTheme.brandCrimson,
                                        isSelected: selectedCategory == category
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }
                        .frame(minHeight: 0)
                    }
                    .cardStyle()
                    .padding(.horizontal)

                    // Item list
                    if store.shoppingState.items.isEmpty {
                        EmptyStateCard(symbol: "cart.fill", title: "清单是空的", subtitle: "先去灶王爷里点菜或看推荐。")
                            .padding(.horizontal)
                    } else if resolvedDays.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(filteredItems) { item in
                                ShoppingItemRow(
                                    item: item,
                                    onToggle: { toggleItem(item) },
                                    onDelete: { deleteItem(item) }
                                )
                            }
                        }
                        .cardStyle()
                        .padding(.horizontal)
                    } else {
                        ForEach(resolvedDays, id: \.self) { day in
                            let items = filteredItems.filter { $0.day == day }
                            if !items.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        Text(day == DateHelper.todayKey ? "今天购物" : day)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text("\(items.count) 项")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.bottom, 4)

                                    ForEach(items) { item in
                                        ShoppingItemRow(
                                            item: item,
                                            onToggle: { toggleItem(item) },
                                            onDelete: { deleteItem(item) }
                                        )
                                    }
                                }
                                .cardStyle()
                                .padding(.horizontal)
                            }
                        }

                        let unassignedItems = filteredItems.filter { $0.day.isEmpty }
                        if !unassignedItems.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("未分配")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    if !resolvedDays.isEmpty {
                                        Button("全部分配") { assignAllUnassigned() }
                                            .font(.caption.weight(.medium))
                                    }
                                }
                                .padding(.bottom, 4)

                                ForEach(unassignedItems) { item in
                                    ShoppingItemRow(
                                        item: item,
                                        onToggle: { toggleItem(item) },
                                        onDelete: { deleteItem(item) }
                                    )
                                    .contextMenu {
                                        ForEach(resolvedDays, id: \.self) { day in
                                            Button("分配到 \(day == DateHelper.todayKey ? "今天" : day)") {
                                                assignItemToDay(item, day: day)
                                            }
                                        }
                                    }
                                }
                            }
                            .cardStyle()
                            .padding(.horizontal)
                        }
                    }

                }
                .padding(.vertical, 8)
            }
            .background(KitchenTheme.background)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                checkoutBottomBar
            }
            .navigationTitle("购物清单")
            .animation(.snappy(duration: 0.22), value: completedCount)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    KitchenBrandMark()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddForm = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddForm) {
                AddShoppingItemSheet(form: $form, shopDays: resolvedDays) {
                    addManualShoppingItem()
                }
            }
            .sheet(isPresented: $showingFixedDays) {
                FixedShopDaysSheet()
            }
            .sheet(isPresented: $showingCheckout) {
                CheckoutSheet(checkedItems: checkedItems)
            }
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
        if let index = store.shoppingState.shopDays.firstIndex(of: day) {
            store.shoppingState.shopDays.remove(at: index)
        } else {
            store.shoppingState.shopDays.append(day)
            store.shoppingState.shopDays.sort()
        }
    }

    private func pendingCount(for day: String) -> Int {
        store.shoppingState.items.filter { !$0.isChecked && $0.day == day }.count
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

    private func assignAllUnassigned() {
        let day = nearestShopDay
        guard !day.isEmpty else { return }
        for i in store.shoppingState.items.indices where store.shoppingState.items[i].day.isEmpty {
            store.shoppingState.items[i].day = day
        }
        store.showToast("已全部分配到 \(day == DateHelper.todayKey ? "今天" : day)")
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
                        store.checkoutShoppingTrip(lineItems: lineItems)
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
