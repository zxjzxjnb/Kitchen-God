import SwiftUI

// MARK: - 大块卡片区
// 顶部概览卡、需要处理卡、分类分区卡。

struct InventoryOverviewCard: View {
    let message: String
    let itemCount: Int
    let totalValue: Double
    let criticalCount: Int
    let upcomingCount: Int
    let onAdd: () -> Void

    private var accent: Color {
        if criticalCount > 0 { return KitchenTheme.danger }
        if upcomingCount > 0 { return KitchenTheme.warning }
        return KitchenTheme.brandGold
    }

    private var title: String {
        itemCount == 0 ? "库存待建立" : "\(itemCount) 项在库"
    }

    private var riskValue: String {
        let total = criticalCount + upcomingCount
        return total == 0 ? "平稳" : "\(total) 项"
    }

    var body: some View {
        KitchenPageHeader(
            eyebrow: "库存状态",
            title: title,
            message: message,
            symbol: "archivebox.fill",
            accent: accent,
            metrics: [
                KitchenMetric(title: "当前库存", value: "\(itemCount) 项", symbol: "shippingbox.fill", accent: KitchenTheme.brandGold),
                KitchenMetric(title: "需要处理", value: riskValue, symbol: criticalCount > 0 ? "exclamationmark.triangle.fill" : "clock.fill", accent: criticalCount > 0 ? KitchenTheme.danger : (upcomingCount > 0 ? KitchenTheme.warning : KitchenTheme.brandGold)),
                KitchenMetric(title: "库存估值", value: totalValue.currencyText, symbol: "eurosign.circle.fill", accent: KitchenTheme.brandGold)
            ],
            actionTitle: "快速入库",
            actionSymbol: "plus.circle.fill",
            action: onAdd
        )
    }
}

struct InventoryFocusCard: View {
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
        .padding(KitchenTheme.Spacing.lg)
        .background(
            tint.opacity(0.6),
            in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.lg, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTheme.Radius.lg, style: .continuous)
                .strokeBorder(accent.opacity(0.30), lineWidth: 1)
        )
    }
}

struct InventoryCategorySectionCard: View {
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
                            .foregroundStyle(KitchenTheme.textPrimary)
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
                .stroke(KitchenTheme.separator.opacity(0.5), lineWidth: 1)
        )
    }
}
