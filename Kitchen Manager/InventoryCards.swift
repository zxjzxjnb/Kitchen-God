import SwiftUI

struct InventorySection: View {
    let title: String
    let items: [InventoryItem]
    let insight: (InventoryItem) -> InventoryItemInsight
    let onAdjust: (InventoryItem, Double) -> Void
    let onDelete: (InventoryItem) -> Void
    let onEdit: (InventoryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    InventoryItemRow(item: item, insight: insight(item), showCategory: false,
                                     onAdjust: { onAdjust(item, $0) },
                                     onDelete: { onDelete(item) }, onEdit: { onEdit(item) })
                    if index < items.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 12)
            .background(KitchenTheme.surface, in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.md))
        }
    }
}
