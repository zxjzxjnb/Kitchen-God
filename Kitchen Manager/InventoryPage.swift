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
                        totalValue: totalEstimatedValue
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
                                accent: criticalItems.isEmpty ? KitchenTheme.warn : KitchenTheme.red,
                                tint: criticalItems.isEmpty ? KitchenTheme.warnTint : KitchenTheme.redTint,
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
        store.showToast("已添加 \(trimmed) 到库存")
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
        store.showToast("已将 \(item.name) 标记为用完")
    }

    private func discardInventoryItem(_ item: InventoryItem) {
        store.recordWaste(for: item)
        store.inventoryItems.removeAll { $0.id == item.id }
        removalCandidate = nil
        store.showToast("已将 \(item.name) 计入浪费")
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

private struct InventoryCategoryGroup: Identifiable {
    let category: String
    let items: [InventoryItem]
    let criticalCount: Int
    let upcomingCount: Int

    var id: String { category }

    var totalValue: Double {
        items.reduce(0) { $0 + $1.estimatedRemainingValue }
    }

    var previewItems: [InventoryItem] {
        Array(items.prefix(3))
    }
}

private struct InventoryItemInsight {
    enum Focus {
        case critical
        case upcoming
    }

    let status: InventoryStatusInfo?
    let focus: Focus?
    let detail: String
    let sortRank: Int
}

private enum InventoryPalette {
    static func color(for category: String) -> Color {
        switch category {
        case "蔬菜": return .green
        case "肉类": return .red
        case "海鲜": return .blue
        case "乳制品": return .mint
        case "主食": return .orange
        case "调料": return .brown
        case "饮料": return .cyan
        case "零食": return .pink
        default: return .gray
        }
    }
}

private struct InventoryOverviewCard: View {
    let message: String
    let itemCount: Int
    let totalValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
            }

            HStack(spacing: 10) {
                InventoryOverviewMetric(title: "当前库存", value: "\(itemCount) 项")
                InventoryOverviewMetric(title: "库存估值", value: totalValue.currencyText)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.accentColor, KitchenTheme.green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, y: 10)
    }
}

private struct InventoryOverviewMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.78))

            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct InventoryCategoryFilter: View {
    @Binding var selectedCategory: String
    let counts: [String: Int]

    private var totalCount: Int {
        counts.values.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    InventoryCategoryChip(
                        title: "全部",
                        count: totalCount,
                        accent: Color.accentColor,
                        isSelected: selectedCategory == "全部"
                    ) {
                        selectedCategory = "全部"
                    }

                    ForEach(KitchenData.categories, id: \.self) { category in
                        InventoryCategoryChip(
                            title: category,
                            count: counts[category, default: 0],
                            accent: InventoryPalette.color(for: category),
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
}

private struct InventoryCategoryChip: View {
    let title: String
    let count: Int
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Text("\(count)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ? Color.white.opacity(0.22) : accent.opacity(0.12),
                        in: Capsule()
                    )
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                isSelected ? accent : KitchenTheme.surfaceElevated,
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : KitchenTheme.borderSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct InventoryFocusCard: View {
    let title: String
    let symbol: String
    let accent: Color
    let tint: Color
    let items: [InventoryItem]
    let summaryTags: [String]
    let isExpanded: Bool
    let showCategory: Bool
    let insight: (InventoryItem) -> InventoryItemInsight
    let onToggle: () -> Void
    let onAdjust: (InventoryItem, Double) -> Void
    let onDelete: (InventoryItem) -> Void
    let onEdit: (InventoryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 12) {
                    Label(title, systemImage: symbol)
                        .font(.headline)
                        .foregroundStyle(accent)

                    Spacer()

                    Text(isExpanded ? "收起" : "展开")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    InventoryItemRow(
                        item: item,
                        insight: insight(item),
                        showCategory: showCategory,
                        onAdjust: { onAdjust(item, $0) },
                        onDelete: { onDelete(item) },
                        onEdit: { onEdit(item) }
                    )

                    if index < items.count - 1 {
                        Divider()
                            .padding(.horizontal, 6)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(summaryTags.enumerated()), id: \.offset) { entry in
                            Text(entry.element)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(accent.opacity(0.12), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.95), KitchenTheme.surfaceElevated],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct InventoryCategorySectionCard: View {
    let section: InventoryCategoryGroup
    let accent: Color
    let isExpanded: Bool
    let showCategory: Bool
    let insight: (InventoryItem) -> InventoryItemInsight
    let issueSummary: (InventoryItem) -> String
    let onToggle: () -> Void
    let onAdjust: (InventoryItem, Double) -> Void
    let onDelete: (InventoryItem) -> Void
    let onEdit: (InventoryItem) -> Void

    private var issueItems: [InventoryItem] {
        section.items.filter { insight($0).focus != nil }
    }

    private var summaryText: String {
        let summaries = issueItems.prefix(2).map(issueSummary)
        if !summaries.isEmpty {
            let extraCount = max(issueItems.count - summaries.count, 0)
            let text = summaries.joined(separator: "、")
            return extraCount > 0 ? "\(text)，还有 \(extraCount) 项" : text
        }
        return "分类清晰，状态稳定"
    }

    private var collapsedStats: [String] {
        let summaries = issueItems.prefix(3).map(issueSummary)
        if !summaries.isEmpty {
            let extraCount = max(issueItems.count - summaries.count, 0)
            return extraCount > 0 ? summaries + ["还有 \(extraCount) 项"] : summaries
        }
        return ["\(section.items.count) 项", "约 \(section.totalValue.currencyText)"]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 12) {
                    Circle()
                        .fill(accent)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(section.category)
                            .font(.headline)
                            .foregroundStyle(KitchenTheme.text)
                        Text(summaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(isExpanded ? "收起" : "展开")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    InventoryItemRow(
                        item: item,
                        insight: insight(item),
                        showCategory: showCategory,
                        onAdjust: { onAdjust(item, $0) },
                        onDelete: { onDelete(item) },
                        onEdit: { onEdit(item) }
                    )

                    if index < section.items.count - 1 {
                        Divider()
                            .padding(.horizontal, 6)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(collapsedStats.enumerated()), id: \.offset) { entry in
                            Text(entry.element)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(accent.opacity(0.12), in: Capsule())
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(KitchenTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KitchenTheme.borderSoft, lineWidth: 1)
        )
    }
}

private struct InventoryItemRow: View {
    let item: InventoryItem
    let insight: InventoryItemInsight
    let showCategory: Bool
    let onAdjust: (Double) -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void

    private var categoryColor: Color {
        InventoryPalette.color(for: item.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(item.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KitchenTheme.text)
                            .lineLimit(1)

                        if showCategory {
                            CategoryTag(
                                title: item.category,
                                tint: categoryColor.opacity(0.14),
                                textColor: categoryColor
                            )
                        }

                        if let status = insight.status {
                            Text(status.text)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(status.color)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }

                    if !insight.detail.isEmpty {
                        Text(insight.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(KitchenTheme.surfaceElevated, in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(item.quantity)\(item.unit)")
                        .font(.title3.weight(.bold).monospacedDigit())

                    HStack(spacing: 10) {
                        Text("约 \(item.estimatedRemainingValue.currencyText)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    InventoryAdjustButton(symbol: "minus") { onAdjust(-1) }
                    InventoryAdjustButton(symbol: "plus") { onAdjust(1) }
                }
            }
        }
        .padding(14)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }

    private var backgroundColor: Color {
        switch insight.focus {
        case .critical:
            return KitchenTheme.redTint.opacity(0.95)
        case .upcoming:
            return KitchenTheme.warnTint.opacity(0.9)
        case nil:
            if insight.status?.level == .warning {
                return KitchenTheme.warnTint.opacity(0.28)
            }
            return KitchenTheme.surface
        }
    }

    private var borderColor: Color {
        switch insight.focus {
        case .critical:
            return KitchenTheme.red.opacity(0.32)
        case .upcoming:
            return KitchenTheme.warn.opacity(0.32)
        case nil:
            return insight.status?.color.opacity(0.24) ?? KitchenTheme.borderSoft
        }
    }
}

private struct InventoryAdjustButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .frame(width: 32, height: 32)
                .background(KitchenTheme.surfaceElevated, in: Circle())
                .overlay(
                    Circle()
                        .stroke(KitchenTheme.borderSoft, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct AddInventorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var form = InventoryForm()
    let onAdd: (InventoryForm) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("名称", text: $form.name)
                    HStack {
                        TextField("数量", text: $form.quantity)
                            .keyboardType(.decimalPad)
                        Picker("单位", selection: $form.unit) {
                            ForEach(KitchenData.units, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    Picker("分类", selection: $form.category) {
                        ForEach(KitchenData.categories, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("参考单价 (€/\(form.unit))", text: $form.unitPrice)
                        .keyboardType(.decimalPad)
                }

                Section("高级设置") {
                    TextField("告急阈值", text: $form.threshold)
                        .keyboardType(.decimalPad)

                    Toggle("启用过期日期", isOn: Binding(
                        get: { form.expiryDate != nil },
                        set: { form.expiryDate = $0 ? Date() : nil }
                    ))

                    if form.expiryDate != nil {
                        DatePicker(
                            "过期日期",
                            selection: Binding(
                                get: { form.expiryDate ?? Date() },
                                set: { form.expiryDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }

                    TextField("新鲜天数", text: $form.freshnessDays)
                        .keyboardType(.numberPad)
                }

                Section {
                    Button("添加到库存") {
                        onAdd(form)
                    }
                    .fontWeight(.semibold)
                    .disabled(form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("快速入库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

struct InventoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: InventoryItem
    let onSave: (InventoryItem) -> Void
    let onDelete: () -> Void

    @State private var quantity: String
    @State private var unitPrice: String
    @State private var threshold: String
    @State private var expiryEnabled: Bool
    @State private var expiryDate: Date
    @State private var freshnessDays: String
    @State private var addedDate: Date

    init(item: InventoryItem, onSave: @escaping (InventoryItem) -> Void, onDelete: @escaping () -> Void) {
        self.item = item
        self.onSave = onSave
        self.onDelete = onDelete
        _quantity = State(initialValue: item.quantity)
        _unitPrice = State(initialValue: item.unitPrice?.cleanString ?? "")
        _threshold = State(initialValue: item.threshold?.cleanString ?? "")
        _expiryEnabled = State(initialValue: item.expiryDate != nil)
        _expiryDate = State(initialValue: item.expiryDate.flatMap(DateHelper.date(from:)) ?? Date())
        _freshnessDays = State(initialValue: item.freshnessDays > 0 ? "\(item.freshnessDays)" : "")
        _addedDate = State(initialValue: DateHelper.date(from: item.addedDate) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(item.name) {
                    HStack {
                        Text("数量 (\(item.unit))")
                        Spacer()
                        TextField("0", text: $quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("参考单价 (€/\(item.unit))")
                        Spacer()
                        TextField("自动估算", text: $unitPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("告急阈值")
                        Spacer()
                        TextField("不提醒", text: $threshold)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Toggle("启用过期日期", isOn: $expiryEnabled)
                    if expiryEnabled {
                        DatePicker("过期日期", selection: $expiryDate, displayedComponents: .date)
                    }
                    HStack {
                        Text("新鲜天数")
                        Spacer()
                        TextField("不追踪", text: $freshnessDays)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker("入库日期", selection: $addedDate, displayedComponents: .date)
                }

                Section {
                    Button("保存") {
                        onSave(
                            InventoryItem(
                                id: item.id,
                                name: item.name,
                                quantity: quantity.isEmpty ? "0" : quantity,
                                unit: item.unit,
                                category: item.category,
                                unitPrice: Double(unitPrice),
                                threshold: Double(threshold),
                                expiryDate: expiryEnabled ? DateHelper.key(for: expiryDate) : nil,
                                freshnessDays: Int(freshnessDays) ?? 0,
                                addedDate: DateHelper.key(for: addedDate),
                                usageSuggestion: item.usageSuggestion
                            )
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)

                    Button("删除", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle("编辑库存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
