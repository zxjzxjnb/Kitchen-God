import SwiftUI

struct InventoryPage: View {
    @Environment(KitchenStore.self) private var store

    @State private var selectedCategory = "全部"
    @State private var showingAddForm = false
    @State private var editingItem: InventoryItem?
    @State private var removalCandidate: InventoryItem?
    @State private var expandedCategory: String?
    @State private var isPriorityExpanded = false

    private var filteredItems: [InventoryItem] {
        selectedCategory == "全部"
            ? store.inventoryItems
            : store.inventoryItems.filter { $0.category == selectedCategory }
    }

    private var categoryCounts: [String: Int] {
        Dictionary(grouping: store.inventoryItems, by: \.category).mapValues { $0.count }
    }

    private var criticalItems: [InventoryItem] {
        filteredItems
            .filter { insight(for: $0).focus == .critical }
            .sorted(by: sortItems)
    }

    private var upcomingItems: [InventoryItem] {
        filteredItems
            .filter { insight(for: $0).focus == .upcoming }
            .sorted(by: sortItems)
    }

    private var priorityItems: [InventoryItem] {
        filteredItems
            .filter { insight(for: $0).focus != nil }
            .sorted(by: sortItems)
    }

    private var categorySections: [InventoryCategoryGroup] {
        let grouped = Dictionary(grouping: filteredItems, by: \.category)
        let categories = selectedCategory == "全部" ? KitchenData.categories : [selectedCategory]

        return categories.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }

            let sortedItems = items.sorted(by: sortItems)
            return InventoryCategoryGroup(
                category: category,
                items: sortedItems,
                criticalCount: sortedItems.filter { insight(for: $0).focus == .critical }.count,
                upcomingCount: sortedItems.filter { insight(for: $0).focus == .upcoming }.count
            )
        }
    }

    private var totalEstimatedValue: Double {
        filteredItems.reduce(0) { $0 + $1.estimatedRemainingValue }
    }

    private var priorityIssueSummaries: [String] {
        priorityItems.map(issueSummary(for:))
    }

    private var overviewMessage: String {
        if filteredItems.isEmpty {
            return selectedCategory == "全部" ? "先添加食材。" : "换个分类看看。"
        }
        if !priorityItems.isEmpty {
            return issueSummaryText(for: priorityItems, limit: 3)
        }
        return "库存状态平稳"
    }

    private var prioritySummaryTags: [String] {
        var tags = Array(priorityIssueSummaries.prefix(3))
        let extraCount = max(priorityIssueSummaries.count - tags.count, 0)
        if extraCount > 0 {
            tags.append("还有 \(extraCount) 项")
        }
        return tags
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    InventoryOverviewCard(
                        message: overviewMessage,
                        itemCount: filteredItems.count,
                        totalValue: totalEstimatedValue,
                        criticalCount: criticalItems.count,
                        upcomingCount: upcomingItems.count,
                        onAdd: { showingAddForm = true }
                    )
                    .padding(.horizontal)

                    InventoryCategoryFilter(
                        selectedCategory: $selectedCategory,
                        counts: categoryCounts
                    )
                    .padding(.horizontal)

                    if filteredItems.isEmpty {
                        EmptyStateCard(
                            symbol: "archivebox.fill",
                            title: "库存为空",
                            subtitle: "先添加食材。"
                        )
                        .padding(.horizontal)
                    } else {
                        if priorityItems.isEmpty {
                            NoAlertCard()
                                .padding(.horizontal)
                        } else {
                            InventoryFocusCard(
                                title: "需要处理",
                                symbol: "clock.badge.exclamationmark.fill",
                                accent: criticalItems.isEmpty ? KitchenTheme.warning : KitchenTheme.danger,
                                tint: criticalItems.isEmpty ? KitchenTheme.warning.opacity(0.12) : KitchenTheme.danger.opacity(0.12),
                                items: priorityItems,
                                summaryTags: prioritySummaryTags,
                                isExpanded: isPriorityExpanded,
                                showCategory: false,
                                insight: insight(for:),
                                onToggle: { isPriorityExpanded.toggle() },
                                onAdjust: { item, delta in adjustQuantity(for: item, delta: delta) },
                                onDelete: prepareRemoval,
                                onEdit: { editingItem = $0 }
                            )
                            .padding(.horizontal)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(categorySections) { section in
                                InventoryCategorySectionCard(
                                    section: section,
                                    accent: InventoryPalette.color(for: section.category),
                                    isExpanded: expandedCategory == section.category,
                                    showCategory: false,
                                    insight: insight(for:),
                                    issueSummary: issueSummary(for:),
                                    onToggle: { toggleCategorySection(section.category) },
                                    onAdjust: { item, delta in adjustQuantity(for: item, delta: delta) },
                                    onDelete: prepareRemoval,
                                    onEdit: { editingItem = $0 }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(KitchenTheme.background)
            .navigationTitle("库存管理")
            .animation(.snappy(duration: 0.28), value: selectedCategory)
            .animation(.snappy(duration: 0.28), value: expandedCategory)
            .animation(.snappy(duration: 0.28), value: isPriorityExpanded)
            .onChange(of: selectedCategory) { _, newValue in
                expandedCategory = newValue == "全部" ? nil : newValue
                isPriorityExpanded = false
            }
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
                AddInventorySheet { addInventoryItem($0) }
            }
            .sheet(item: $editingItem) { item in
                InventoryEditSheet(
                    item: item,
                    onSave: { updated in
                        guard let index = store.inventoryItems.firstIndex(where: { $0.id == updated.id }) else { return }
                        store.inventoryItems[index] = updated
                        store.showToast("已更新 \(updated.name)")
                    },
                    onDelete: { prepareRemoval(for: item) }
                )
            }
            .confirmationDialog(
                removalCandidate == nil ? "移除库存" : "如何处理 \(removalCandidate?.name ?? "")？",
                isPresented: Binding(
                    get: { removalCandidate != nil },
                    set: { if !$0 { removalCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let item = removalCandidate {
                    Button("标记为已用完") { consumeInventoryItem(item) }
                    Button("标记为丢弃并计入浪费 \(item.estimatedRemainingValue.currencyText)", role: .destructive) {
                        discardInventoryItem(item)
                    }
                }
                Button("取消", role: .cancel) { removalCandidate = nil }
            } message: {
                if let item = removalCandidate {
                    Text("剩余价值约 \(item.estimatedRemainingValue.currencyText)。")
                }
            }
        }
    }

    private func addInventoryItem(_ form: InventoryForm) {
        let trimmed = form.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let freshnessValue = Int(form.freshnessDays) ?? KitchenData.defaultFreshness[form.category] ?? 0
        let item = InventoryItem(
            name: trimmed,
            quantity: form.quantity.isEmpty ? "0" : form.quantity,
            unit: form.unit,
            category: form.category,
            unitPrice: Double(form.unitPrice),
            threshold: Double(form.threshold),
            expiryDate: form.expiryDate.map(DateHelper.key(for:)),
            freshnessDays: freshnessValue,
            addedDate: DateHelper.todayKey,
            usageSuggestion: InventoryRecommendation.suggestion(for: trimmed, category: form.category)
        )
        store.inventoryItems.append(item)
        store.showToast("\(trimmed),我记下了。", kind: .success)
        showingAddForm = false
    }

    private func adjustQuantity(for item: InventoryItem, delta: Double) {
        guard let index = store.inventoryItems.firstIndex(where: { $0.id == item.id }) else { return }
        let current = Double(store.inventoryItems[index].quantity) ?? 0
        let updated = max(0, current + delta)
        store.inventoryItems[index].quantity = updated.cleanString
    }

    private func prepareRemoval(for item: InventoryItem) {
        removalCandidate = item
    }

    private func toggleCategorySection(_ category: String) {
        expandedCategory = expandedCategory == category ? nil : category
    }

    private func consumeInventoryItem(_ item: InventoryItem) {
        store.inventoryItems.removeAll { $0.id == item.id }
        removalCandidate = nil
        store.showToast("记下了,这份\(item.name)吃完了。", kind: .success)
    }

    private func discardInventoryItem(_ item: InventoryItem) {
        store.recordWaste(for: item)
        store.inventoryItems.removeAll { $0.id == item.id }
        removalCandidate = nil
        store.showToast("可惜,这份\(item.name)算浪费了。", kind: .warning)
    }

    private func sortItems(_ lhs: InventoryItem, _ rhs: InventoryItem) -> Bool {
        let leftInsight = insight(for: lhs)
        let rightInsight = insight(for: rhs)

        if leftInsight.sortRank != rightInsight.sortRank {
            return leftInsight.sortRank < rightInsight.sortRank
        }

        let leftCategoryOrder = KitchenData.categories.firstIndex(of: lhs.category) ?? Int.max
        let rightCategoryOrder = KitchenData.categories.firstIndex(of: rhs.category) ?? Int.max

        if leftCategoryOrder != rightCategoryOrder {
            return leftCategoryOrder < rightCategoryOrder
        }

        return lhs.name.localizedCompare(rhs.name) == .orderedAscending
    }

    private func issueSummaryText(for items: [InventoryItem], limit: Int) -> String {
        let summaries = items.prefix(limit).map(issueSummary(for:))
        let extraCount = max(items.count - summaries.count, 0)
        let text = summaries.joined(separator: "、")
        return extraCount > 0 ? "\(text)，还有 \(extraCount) 项" : text
    }

    private func issueSummary(for item: InventoryItem) -> String {
        if let expiryKey = item.expiryDate, let days = daysUntil(dateKey: expiryKey) {
            if days < 0 {
                return "\(item.name)已过期"
            }
            if days == 0 {
                return "\(item.name)今天到期"
            }
            if days <= 3 {
                return "\(item.name)临期"
            }
        }

        if item.freshnessDays > 0, let addedDate = DateHelper.date(from: item.addedDate) {
            let usedDays = Calendar.current.dateComponents([.day], from: addedDate, to: Date()).day ?? 0
            let leftDays = item.freshnessDays - usedDays
            if leftDays <= 0 {
                return "\(item.name)不新鲜"
            }
            if leftDays <= 2 {
                return "\(item.name)新鲜期临期"
            }
        }

        if let threshold = item.threshold, item.quantityValue <= threshold {
            return "\(item.name)库存不足"
        }

        return "\(item.name)需要处理"
    }

    private func insight(for item: InventoryItem) -> InventoryItemInsight {
        let status = AlertEngine.status(for: item)

        if let expiryKey = item.expiryDate, let days = daysUntil(dateKey: expiryKey) {
            let dateText = shortDateText(from: expiryKey)

            if days < 0 {
                return InventoryItemInsight(
                    status: status,
                    focus: .critical,
                    detail: "",
                    sortRank: 0
                )
            }

            if days == 0 {
                return InventoryItemInsight(
                    status: status,
                    focus: .critical,
                    detail: "",
                    sortRank: 1
                )
            }

            if days <= 3 {
                return InventoryItemInsight(
                    status: status,
                    focus: .upcoming,
                    detail: "",
                    sortRank: 10 + days
                )
            }

            return InventoryItemInsight(
                status: status,
                focus: nil,
                detail: "到期日 \(dateText)",
                sortRank: 120 + days
            )
        }

        if item.freshnessDays > 0, let addedDate = DateHelper.date(from: item.addedDate) {
            let usedDays = Calendar.current.dateComponents([.day], from: addedDate, to: Date()).day ?? 0
            let leftDays = item.freshnessDays - usedDays
            let addedText = DateHelper.monthDayString(addedDate)

            if leftDays <= 0 {
                return InventoryItemInsight(
                    status: status,
                    focus: .critical,
                    detail: "\(addedText) 入库，已存放 \(usedDays) 天",
                    sortRank: 5
                )
            }

            if leftDays <= 2 {
                return InventoryItemInsight(
                    status: status,
                    focus: .upcoming,
                    detail: "新鲜期还剩 \(leftDays) 天",
                    sortRank: 20 + leftDays
                )
            }

            return InventoryItemInsight(
                status: status,
                focus: nil,
                detail: "\(addedText) 入库，建议 \(item.freshnessDays) 天内用完",
                sortRank: 150 + usedDays
            )
        }

        if let threshold = item.threshold, item.quantityValue <= threshold {
            return InventoryItemInsight(
                status: status,
                focus: nil,
                detail: "库存偏低，记得补货",
                sortRank: 80
            )
        }

        return InventoryItemInsight(
            status: status,
            focus: nil,
            detail: item.usageSuggestion,
            sortRank: 220
        )
    }

    private func shortDateText(from key: String) -> String {
        guard let date = DateHelper.date(from: key) else { return key }
        return DateHelper.monthDayString(date)
    }

    private func daysUntil(dateKey: String) -> Int? {
        guard let date = DateHelper.date(from: dateKey) else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: date)
        return Calendar.current.dateComponents([.day], from: start, to: end).day
    }
}
