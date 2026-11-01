import SwiftUI

/// One assessment drives dashboard alerts, inventory grouping and row status.
enum AlertEngine {
    private enum Kind { case expired, expiringSoon, lowStock, notFresh }
    private struct Issue {
        let kind: Kind
        let text: String
        let rank: Int
        let critical: Bool
    }

    static func compute(inventory: [InventoryItem], now: Date = Date()) -> AlertBundle {
        var bundle = AlertBundle(expired: [], expiringSoon: [], lowStock: [], notFresh: [])
        for item in inventory {
            for issue in issues(for: item, now: now) {
                let alert = AlertItem(id: item.id, label: "\(item.name)（\(issue.text)）")
                switch issue.kind {
                case .expired: bundle.expired.append(alert)
                case .expiringSoon: bundle.expiringSoon.append(alert)
                case .lowStock: bundle.lowStock.append(alert)
                case .notFresh: bundle.notFresh.append(alert)
                }
            }
        }
        return bundle
    }

    static func status(for item: InventoryItem) -> InventoryStatusInfo? {
        insight(for: item).status
    }

    static func insight(for item: InventoryItem, now: Date = Date()) -> InventoryItemInsight {
        if let issue = issues(for: item, now: now).min(by: { $0.rank < $1.rank }) {
            return InventoryItemInsight(
                status: InventoryStatusInfo(text: issue.text,
                                            color: issue.critical ? KitchenTheme.danger : KitchenTheme.warning,
                                            level: issue.critical ? .danger : .warning),
                focus: issue.critical ? .critical : .upcoming,
                detail: "", sortRank: issue.rank
            )
        }
        let status = item.expiryDate.map {
            InventoryStatusInfo(text: "到期 \($0)", color: KitchenTheme.textSecondary, level: .normal)
        }
        return InventoryItemInsight(status: status, focus: nil, detail: "", sortRank: 200)
    }

    private static func issues(for item: InventoryItem, now: Date) -> [Issue] {
        var result: [Issue] = []
        let expiryDays = item.expiryDate.flatMap { daysUntil(dateKey: $0, now: now) }
        if let days = expiryDays {
            if days < 0 {
                result.append(Issue(kind: .expired, text: "已过期 \(-days) 天", rank: 0, critical: true))
            } else if days <= 3 {
                result.append(Issue(kind: .expiringSoon,
                                    text: days == 0 ? "今天到期" : "\(days) 天后到期",
                                    rank: days == 0 ? 1 : 10 + days, critical: days == 0))
            }
        }
        // Expiry and freshness are independent; a distant expiry must not mask stale food.
        if (expiryDays ?? 1) >= 0, item.freshnessDays > 0,
           let days = daysUntil(dateKey: item.addedDate, now: now) {
            let left = item.freshnessDays + days
            if left <= 0 {
                result.append(Issue(kind: .notFresh, text: "不新鲜", rank: 5, critical: true))
            } else if left <= 2, (expiryDays ?? 99) > 3 {
                result.append(Issue(kind: .expiringSoon, text: "新鲜期剩 \(left) 天", rank: 20 + left, critical: false))
            }
        }
        if let threshold = item.threshold, item.quantityValue <= threshold {
            result.append(Issue(kind: .lowStock, text: "库存不足", rank: 80, critical: false))
        }
        return result
    }

    private static func daysUntil(dateKey: String, now: Date) -> Int? {
        guard let date = DateHelper.date(from: dateKey) else { return nil }
        return Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: now),
            to: Calendar.current.startOfDay(for: date)).day
    }
}
