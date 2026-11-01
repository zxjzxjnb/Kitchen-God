import SwiftUI

struct InventoryPage: View {
    @Environment(KitchenStore.self) private var store

    @State private var selectedCategory = "全部"
    @State private var showingAddForm = false
    @State private var editingItem: InventoryItem?
    @State private var removalCandidate: InventoryItem?
    private var filteredItems: [InventoryItem] {
        store.inventoryItems.filter { selectedCategory == "全部" || $0.category == selectedCategory }
    }

    private var categoryCounts: [String: Int] {
        Dictionary(grouping: store.inventoryItems, by: \.category).mapValues { $0.count }
    }

    private var priorityItems: [InventoryItem] {
        filteredItems.filter { insight(for: $0).focus != nil }.sorted(by: sortItems)
    }

    private var categorySections: [InventoryCategoryGroup] {
        let grouped = Dictionary(grouping: filteredItems.filter { insight(for: $0).focus == nil }, by: \.category)
        let categories = KitchenData.categories + grouped.keys.filter { !KitchenData.categories.contains($0) }.sorted()
        return categories.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return InventoryCategoryGroup(category: category, items: items.sorted(by: sortItems),
                                          criticalCount: 0, upcomingCount: 0)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    InventoryCategoryFilter(selectedCategory: $selectedCategory, counts: categoryCounts)

                    if filteredItems.isEmpty {
                        EmptyStateCard(symbol: "archivebox", title: "暂无食材", subtitle: "")
                    } else {
                        if !priorityItems.isEmpty {
                            inventorySection(title: "需要处理", items: priorityItems)
                        }
                        ForEach(categorySections) { section in
                            inventorySection(title: section.category, items: section.items)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(KitchenTheme.background)
            .navigationTitle("库存管理")
            .animation(.snappy(duration: 0.28), value: selectedCategory)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddForm = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加食材")
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

    private func insight(for item: InventoryItem) -> InventoryItemInsight {
        AlertEngine.insight(for: item)
    }

    private func inventorySection(title: String, items: [InventoryItem]) -> some View {
        InventorySection(title: title, items: items, insight: insight(for:),
                         onAdjust: { item, delta in adjustQuantity(for: item, delta: delta) },
                         onDelete: prepareRemoval, onEdit: { editingItem = $0 })
    }
}
