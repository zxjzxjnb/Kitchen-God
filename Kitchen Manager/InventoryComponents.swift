import SwiftUI

// MARK: - 可复用的小组件
// 分类筛选条、分类胶囊按钮、单条库存行、加减按钮。

struct InventoryCategoryFilter: View {
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
                        accent: KitchenTheme.brandGold,
                        isSelected: selectedCategory == "全部"
                    ) {
                        selectedCategory = "全部"
                    }

                    ForEach(KitchenData.categories, id: \.self) { category in
                        InventoryCategoryChip(
                            title: category,
                            count: counts[category, default: 0],
                            accent: KitchenTheme.brandGold,
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

struct InventoryCategoryChip: View {
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
                isSelected ? KitchenTheme.brandCrimson : KitchenTheme.surfaceElevated,
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? KitchenTheme.brandGold.opacity(0.38) : KitchenTheme.separator.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct InventoryItemRow: View {
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
                            .foregroundStyle(KitchenTheme.textPrimary)
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
            return KitchenTheme.danger.opacity(0.12)
        case .upcoming:
            return KitchenTheme.warning.opacity(0.12)
        case nil:
            if insight.status?.level == .warning {
                return KitchenTheme.warning.opacity(0.04)
            }
            return KitchenTheme.surface
        }
    }

    private var borderColor: Color {
        switch insight.focus {
        case .critical:
            return KitchenTheme.danger.opacity(0.32)
        case .upcoming:
            return KitchenTheme.warning.opacity(0.32)
        case nil:
            return insight.status?.color.opacity(0.24) ?? KitchenTheme.separator.opacity(0.5)
        }
    }
}

struct InventoryAdjustButton: View {
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
                        .stroke(KitchenTheme.separator.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
// 套路一：组件只需要普通值 + 闭包，直接喂样例数据即可。
// InventoryItemRow 不依赖 store，只要造一个样例食材和一个 insight。
#Preview("单条库存行") {
    InventoryItemRow(
        item: InventoryItem.samples[0],
        insight: InventoryItemInsight(
            status: nil,
            focus: .upcoming,
            detail: "新鲜期还剩 1 天",
            sortRank: 0
        ),
        showCategory: true,
        onAdjust: { _ in },   // 占位：Preview 里不需要真的做事
        onDelete: {},
        onEdit: {}
    )
    .padding()
}

// 套路二：组件有 @Binding。用 @Previewable @State 造一个能交互的真状态，
// 这样在 Preview 里点击分类胶囊也能看到选中态切换。
#Preview("分类筛选条") {
    @Previewable @State var category = "全部"
    return InventoryCategoryFilter(
        selectedCategory: $category,
        counts: ["蔬菜": 3, "肉类": 2, "乳制品": 1]
    )
    .padding()
}
