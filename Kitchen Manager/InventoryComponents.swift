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

                    ForEach(KitchenData.categories + counts.keys.filter { !KitchenData.categories.contains($0) }.sorted(), id: \.self) { category in
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
            .frame(minHeight: 44)
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
        .accessibilityLabel("\(title)，\(count) 项")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct InventoryItemRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let item: InventoryItem
    let insight: InventoryItemInsight
    let showCategory: Bool
    let onAdjust: (Double) -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    editButton
                    quantityControls.frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 8) {
                    editButton
                    quantityControls
                }
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("编辑", action: onEdit)
            Button("移除", role: .destructive, action: onDelete)
        }
    }

    private var editButton: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let status = insight.status {
                    Text(status.text)
                        .font(.caption)
                        .foregroundStyle(status.color)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("编辑\(item.name)")
        .accessibilityValue(insight.status?.text ?? "")
    }

    private var quantityControls: some View {
        HStack(spacing: 0) {
            InventoryAdjustButton(symbol: "minus", label: "减少\(item.name) 1\(item.unit)") { onAdjust(-1) }
                .disabled(item.quantityValue <= 0)
            Text("\(item.quantity)\(item.unit)")
                .font(.subheadline.monospacedDigit())
                .fixedSize()
            InventoryAdjustButton(symbol: "plus", label: "增加\(item.name) 1\(item.unit)") { onAdjust(1) }
        }
    }
}

struct InventoryAdjustButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(KitchenTheme.background, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
