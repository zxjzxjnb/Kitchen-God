import SwiftUI

// MARK: - 库存页面的支撑类型(非界面)
// 这些类型原本是 InventoryPage.swift 里的 `private` 声明，
// 拆分到独立文件后必须改成默认的 internal，否则其它文件看不到它们。

struct InventoryCategoryGroup: Identifiable {
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

struct InventoryItemInsight {
    enum Focus {
        case critical
        case upcoming
    }

    let status: InventoryStatusInfo?
    let focus: Focus?
    let detail: String
    let sortRank: Int
}

enum InventoryPalette {
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
