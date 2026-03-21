import SwiftUI

enum KitchenData {
    static let categories = ["蔬菜", "肉类", "海鲜", "乳制品", "主食", "调料", "饮料", "零食", "其他"]
    static let units = ["个", "克", "斤", "袋", "瓶", "盒", "束", "升", "罐", "片", "根", "颗", "份"]
    static let budgetCategories = ["买菜", "外卖", "零食", "饮料", "餐厅", "其他"]
    static let defaultFreshness: [String: Int] = ["肉类": 2, "海鲜": 1, "蔬菜": 5, "乳制品": 7]

    static func categoryGuess(for name: String) -> String {
        let normalized = normalizedIngredientName(name)

        if ["番茄", "西红柿", "青菜", "生菜", "菠菜", "芦笋", "洋葱", "土豆", "柠檬", "牛油果", "黄瓜", "胡萝卜", "西兰花", "蘑菇", "菌菇", "蒜", "姜", "葱", "辣椒"].contains(where: { normalized.contains($0) }) {
            return "蔬菜"
        }
        if ["牛腩", "鸡胸肉", "猪肉", "牛肉", "鸡腿", "鸡翅", "肉末", "培根"].contains(where: { normalized.contains($0) }) {
            return "肉类"
        }
        if ["三文鱼", "虾仁", "虾", "鱼片", "带鱼", "鱿鱼", "贝类"].contains(where: { normalized.contains($0) }) {
            return "海鲜"
        }
        if ["牛奶", "鸡蛋", "豆腐", "酸奶", "奶酪", "黄油"].contains(where: { normalized.contains($0) }) {
            return "乳制品"
        }
        if ["米饭", "米", "面条", "意面", "挂面", "面粉", "馒头", "燕麦", "吐司"].contains(where: { normalized.contains($0) }) {
            return "主食"
        }
        if ["油", "盐", "醋", "生抽", "老抽", "蚝油", "料酒", "淀粉", "胡椒", "糖", "豆瓣酱", "番茄酱", "芝麻油", "香油", "孜然", "咖喱"].contains(where: { normalized.contains($0) }) {
            return "调料"
        }
        if ["可乐", "果汁", "咖啡", "茶", "气泡水"].contains(where: { normalized.contains($0) }) {
            return "饮料"
        }
        return "其他"
    }

    static func unitGuess(for name: String, category: String = "") -> String {
        let n = normalizedIngredientName(name)
        // Specific name-based matches
        if ["油", "生抽", "老抽", "蚝油", "料酒", "醋", "酱油", "芝麻油", "香油"].contains(where: { n.contains($0) }) { return "瓶" }
        if ["酱", "番茄酱", "豆瓣酱"].contains(where: { n.contains($0) }) { return "罐" }
        if ["盐", "糖", "淀粉", "面粉", "胡椒", "孜然", "咖喱"].contains(where: { n.contains($0) }) { return "袋" }
        if ["鸡蛋", "蛋"].contains(where: { n.contains($0) }) { return "个" }
        if ["牛奶", "酸奶", "豆腐"].contains(where: { n.contains($0) }) { return "盒" }
        if ["奶酪", "黄油"].contains(where: { n.contains($0) }) { return "块" }
        if ["米", "面条", "意面", "挂面", "燕麦"].contains(where: { n.contains($0) }) { return "袋" }
        if ["吐司", "馒头", "面包"].contains(where: { n.contains($0) }) { return "袋" }
        if ["可乐", "果汁", "气泡水", "咖啡"].contains(where: { n.contains($0) }) { return "瓶" }
        if ["茶"].contains(where: { n.contains($0) }) { return "盒" }
        if ["番茄", "土豆", "洋葱", "柠檬", "牛油果", "苹果", "橙"].contains(where: { n.contains($0) }) { return "个" }
        if ["葱", "芦笋", "胡萝卜", "黄瓜"].contains(where: { n.contains($0) }) { return "根" }
        if ["青菜", "菠菜", "生菜"].contains(where: { n.contains($0) }) { return "束" }
        if ["蘑菇", "菌菇", "蒜", "姜", "辣椒"].contains(where: { n.contains($0) }) { return "个" }
        if ["虾仁", "鱼片", "鸡胸肉", "牛腩", "猪肉", "培根", "三文鱼"].contains(where: { n.contains($0) }) { return "份" }
        // Category-based fallback
        let cat = category.isEmpty ? categoryGuess(for: name) : category
        switch cat {
        case "蔬菜": return "个"
        case "肉类", "海鲜": return "份"
        case "乳制品": return "盒"
        case "主食": return "袋"
        case "调料": return "瓶"
        case "饮料": return "瓶"
        case "零食": return "袋"
        default: return "个"
        }
    }

    static func normalizedIngredientName(_ name: String) -> String {
        let trimmed = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let punctuationStripped = trimmed.replacingOccurrences(
            of: "[\\s、,，：:（）()·]",
            with: "",
            options: .regularExpression
        )

        let cleanupTokens = ["新鲜", "适量", "少许", "少量", "一些", "切片", "切丝", "切末", "切丁", "碎", "末"]
        return cleanupTokens.reduce(punctuationStripped) { partial, token in
            partial.replacingOccurrences(of: token, with: "")
        }
    }

    static func isLikelySameIngredient(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalizedIngredientName(lhs)
        let right = normalizedIngredientName(rhs)

        guard !left.isEmpty, !right.isEmpty else { return false }
        return left == right || left.contains(right) || right.contains(left)
    }

    static func estimatedUnitPrice(for name: String, category: String, unit: String) -> Double {
        let nameOverrides: [(String, Double)] = [
            ("鸡蛋", 0.35),
            ("牛奶", 1.80),
            ("豆腐", 1.60),
            ("鸡胸肉", 4.60),
            ("牛腩", 8.50),
            ("虾仁", 5.60),
            ("三文鱼", 7.80),
            ("番茄", 0.80),
            ("土豆", 0.70),
            ("洋葱", 0.65),
            ("青菜", 1.40),
            ("米饭", 1.20),
            ("面条", 1.80),
            ("意面", 2.20),
            ("蒜", 0.50),
            ("姜", 0.60),
            ("生抽", 3.80),
            ("食用油", 7.90)
        ]

        if let override = nameOverrides.first(where: { name.contains($0.0) }) {
            return override.1
        }

        switch category {
        case "蔬菜":
            return ["个", "颗", "根"].contains(unit) ? 0.90 : 1.60
        case "肉类":
            return unit == "份" ? 4.80 : 6.20
        case "海鲜":
            return unit == "份" ? 5.80 : 6.80
        case "乳制品":
            return ["盒", "瓶"].contains(unit) ? 1.90 : 0.40
        case "主食":
            return 2.30
        case "调料":
            return ["瓶", "罐"].contains(unit) ? 4.20 : 2.60
        case "饮料":
            return 2.40
        case "零食":
            return 2.90
        default:
            return 2.00
        }
    }
}

enum DateHelper {
    static let weekdayNames = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    
    // Performance improvement: reusable date formatter
    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let mdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()
    
    private static let ymFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()
    
    private static let monthTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月账单"
        return f
    }()

    nonisolated static var todayKey: String {
        key(for: Date())
    }

    nonisolated static func key(for date: Date) -> String {
        return keyFormatter.string(from: date)
    }

    nonisolated static func date(from key: String) -> Date? {
        return keyFormatter.date(from: key)
    }

    static func weekStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let normalized = weekday == 1 ? 7 : weekday - 1
        return calendar.date(byAdding: .day, value: -(normalized - 1), to: calendar.startOfDay(for: date)) ?? date
    }

    static func weekDates(from weekStart: Date) -> [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    static func monthDayString(_ date: Date) -> String {
        return mdFormatter.string(from: date)
    }

    static func weekdayName(for date: Date) -> String {
        let index = max(0, min(6, Calendar.current.component(.weekday, from: date) - 2))
        return weekdayNames[index < 0 ? 6 : index]
    }

    static func monthKey(for date: Date) -> String {
        return ymFormatter.string(from: date)
    }

    static func monthTitle(for date: Date) -> String {
        return monthTitleFormatter.string(from: date)
    }
}

enum InventoryRecommendation {
    static func suggestion(for name: String, category: String) -> String {
        if category == "调料" {
            return "建议和其他调料一起集中补货"
        }
        if name.contains("豆腐") {
            return "优先做菌菇豆腐汤或麻婆豆腐"
        }
        if name.contains("牛奶") {
            return "优先做奶昔、麦片或法式吐司"
        }
        if category == "蔬菜" {
            return "适合做快炒、沙拉或配菜"
        }
        if category == "肉类" || category == "海鲜" {
            return "建议尽快安排晚餐主菜"
        }
        return "优先安排进本周菜单"
    }
}

extension Double {
    var cleanString: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.1f", self)
    }

    var currencyText: String {
        "€" + String(format: "%.2f", self)
    }
}

extension Optional where Wrapped == Double {
    init(_ text: String) {
        if let value = Double(text) {
            self = value
        } else {
            self = nil
        }
    }
}
