import SwiftUI

enum AlertEngine {
    static func compute(inventory: [InventoryItem]) -> AlertBundle {
        var expired: [AlertItem] = []
        var expiringSoon: [AlertItem] = []
        var lowStock: [AlertItem] = []
        var notFresh: [AlertItem] = []

        for item in inventory {
            if let expiryDate = item.expiryDate, let days = daysUntil(dateKey: expiryDate) {
                if days < 0 {
                    expired.append(AlertItem(id: item.id, label: "\(item.name)（过期 \(-days) 天）"))
                } else if days <= 3 {
                    expiringSoon.append(AlertItem(id: item.id, label: "\(item.name)（临期，还剩 \(days) 天）"))
                }
            }

            if item.freshnessDays > 0, let addedDate = DateHelper.date(from: item.addedDate) {
                let usedDays = Calendar.current.dateComponents([.day], from: addedDate, to: Date()).day ?? 0
                let left = item.freshnessDays - usedDays
                let expiryDays = item.expiryDate.flatMap { daysUntil(dateKey: $0) }
                let alreadyExpired = (expiryDays ?? 1) < 0

                if !alreadyExpired {
                    if left <= 0 {
                        notFresh.append(AlertItem(id: item.id, label: "\(item.name)（不新鲜，已存 \(usedDays) 天）"))
                    } else if left <= 2, !((expiryDays ?? 99) <= 3) {
                        expiringSoon.append(AlertItem(id: item.id, label: "\(item.name)（新鲜期临期，还剩 \(left) 天）"))
                    }
                }
            }

            if let threshold = item.threshold, let quantity = Double(item.quantity), quantity <= threshold {
                lowStock.append(AlertItem(id: item.id, label: "\(item.name)（库存不足，剩 \(item.quantity)\(item.unit)）"))
            }
        }

        return AlertBundle(expired: expired, expiringSoon: expiringSoon, lowStock: lowStock, notFresh: notFresh)
    }

    static func status(for item: InventoryItem) -> InventoryStatusInfo? {
        if let expiry = item.expiryDate, let days = daysUntil(dateKey: expiry) {
            if days < 0 {
                return InventoryStatusInfo(text: "已过期 \(-days) 天", color: KitchenTheme.danger, level: .danger)
            }
            if days == 0 {
                return InventoryStatusInfo(text: "今天到期", color: KitchenTheme.danger, level: .danger)
            }
            if days <= 3 {
                return InventoryStatusInfo(text: "临期，还剩 \(days) 天", color: KitchenTheme.warning, level: .warning)
            }
            return InventoryStatusInfo(text: "到期 \(expiry)", color: KitchenTheme.textSecondary, level: .normal)
        }

        if item.freshnessDays > 0, let addedDate = DateHelper.date(from: item.addedDate) {
            let usedDays = Calendar.current.dateComponents([.day], from: addedDate, to: Date()).day ?? 0
            let left = item.freshnessDays - usedDays
            if left <= 0 {
                return InventoryStatusInfo(text: "不新鲜", color: KitchenTheme.danger, level: .danger)
            }
            if left <= 2 {
                return InventoryStatusInfo(text: "新鲜期临期，还剩 \(left) 天", color: KitchenTheme.warning, level: .warning)
            }
        }

        if let threshold = item.threshold, let quantity = Double(item.quantity), quantity <= threshold {
            return InventoryStatusInfo(text: "库存不足", color: KitchenTheme.warning, level: .warning)
        }

        return nil
    }

    nonisolated private static func daysUntil(dateKey: String) -> Int? {
        guard let date = DateHelper.date(from: dateKey) else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: date)
        return Calendar.current.dateComponents([.day], from: start, to: end).day
    }
}
