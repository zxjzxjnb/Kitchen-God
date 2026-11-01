import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case home
    case mealPlan
    case shopping
    case inventory
    case budget

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "首页"
        case .mealPlan: return "菜单"
        case .shopping: return "购物清单"
        case .inventory: return "库存管理"
        case .budget: return "厨房成本"
        }
    }

    var shortTitle: String {
        switch self {
        case .home: return "首页"
        case .mealPlan: return "菜单"
        case .shopping: return "购物"
        case .inventory: return "库存"
        case .budget: return "成本"
        }
    }

    var symbolName: String {
        switch self {
        case .home: return "house"
        case .mealPlan: return "menucard"
        case .shopping: return "cart"
        case .inventory: return "archivebox"
        case .budget: return "banknote"
        }
    }
}

enum MealSlot: String, CaseIterable, Identifiable, Hashable, Codable {
    case breakfast
    case lunch
    case dinner
    case drinks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: return "早餐"
        case .lunch: return "午餐"
        case .dinner: return "晚餐"
        case .drinks: return "饮品"
        }
    }

    var symbolName: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .drinks: return "cup.and.saucer"
        }
    }
}

enum AIChefMode: CaseIterable, Identifiable, Hashable {
    case input
    case suggest

    var id: String { title }

    var title: String {
        switch self {
        case .input: return "点菜"
        case .suggest: return "推荐"
        }
    }

    var symbolName: String {
        switch self {
        case .input: return "fork.knife"
        case .suggest: return "sparkles"
        }
    }
}

struct ShoppingState: Codable {
    var shopDays: [String]
    var items: [ShoppingItem]
    /// Recurring weekly shopping days (1=Mon ... 7=Sun)
    var fixedShopWeekdays: Set<Int>

    static let samples = ShoppingState(
        shopDays: [DateHelper.todayKey, DateHelper.key(for: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date())],
        items: [
            ShoppingItem(name: "鸡蛋", quantity: "12", unit: "个", category: "乳制品", day: "", isChecked: false, estimatedUnitPrice: 0.35),
            ShoppingItem(name: "生抽", quantity: "1", unit: "瓶", category: "调料", day: DateHelper.todayKey, isChecked: false, estimatedUnitPrice: 3.80),
            ShoppingItem(name: "虾仁", quantity: "1", unit: "盒", category: "海鲜", day: "", isChecked: true, estimatedUnitPrice: 5.60)
        ],
        fixedShopWeekdays: [6] // Saturday by default
    )

    init(shopDays: [String] = [], items: [ShoppingItem] = [], fixedShopWeekdays: Set<Int> = []) {
        self.shopDays = shopDays
        self.items = items
        self.fixedShopWeekdays = fixedShopWeekdays
    }

    enum CodingKeys: String, CodingKey {
        case shopDays, items, fixedShopWeekdays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shopDays = try container.decodeIfPresent([String].self, forKey: .shopDays) ?? []
        items = try container.decodeIfPresent([ShoppingItem].self, forKey: .items) ?? []
        fixedShopWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .fixedShopWeekdays) ?? []
    }

    /// Group every saved item independently of the shopping schedule.
    func itemGroups(category: String = "全部") -> [ShoppingDayGroup] {
        let visible = items.filter { category == "全部" || $0.category == category }
        let grouped = Dictionary(grouping: visible, by: \.day)
        return grouped.keys.sorted {
            if $0.isEmpty { return false }
            if $1.isEmpty { return true }
            return $0 < $1
        }.map { ShoppingDayGroup(day: $0, items: grouped[$0] ?? []) }
    }

    /// Merge fixed weekdays (for this week) with manually selected shopDays
    func resolvedShopDays(for weekDates: [Date]) -> [String] {
        var result = Set(shopDays)
        for date in weekDates {
            let weekday = Calendar.current.component(.weekday, from: date)
            // convert Sunday=1...Saturday=7  →  Mon=1...Sun=7
            let normalized = weekday == 1 ? 7 : weekday - 1
            if fixedShopWeekdays.contains(normalized) {
                result.insert(DateHelper.key(for: date))
            }
        }
        return result.sorted()
    }
}

struct ShoppingDayGroup: Identifiable {
    let day: String
    let items: [ShoppingItem]
    var id: String { day }

    func title(today: String = DateHelper.todayKey) -> String {
        if day.isEmpty { return "未分配" }
        if day == today { return "今天" }
        if day < today && items.contains(where: { !$0.isChecked }) { return "逾期 · \(day)" }
        return day
    }
}

struct ShoppingItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var quantity: String
    var unit: String
    var category: String
    var day: String
    var isChecked: Bool
    var estimatedUnitPrice: Double?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: String,
        unit: String,
        category: String,
        day: String,
        isChecked: Bool,
        estimatedUnitPrice: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.day = day
        self.isChecked = isChecked
        self.estimatedUnitPrice = estimatedUnitPrice
    }
}

struct InventoryItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var quantity: String
    var unit: String
    var category: String
    var unitPrice: Double?
    var threshold: Double?
    var expiryDate: String?
    var freshnessDays: Int
    var addedDate: String
    var usageSuggestion: String

    init(
        id: UUID = UUID(),
        name: String,
        quantity: String,
        unit: String,
        category: String,
        unitPrice: Double?,
        threshold: Double?,
        expiryDate: String?,
        freshnessDays: Int,
        addedDate: String,
        usageSuggestion: String
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.unitPrice = unitPrice
        self.threshold = threshold
        self.expiryDate = expiryDate
        self.freshnessDays = freshnessDays
        self.addedDate = addedDate
        self.usageSuggestion = usageSuggestion
    }

    static let samples = [
        InventoryItem(name: "牛奶", quantity: "1", unit: "盒", category: "乳制品", unitPrice: 1.80, threshold: 1, expiryDate: DateHelper.key(for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()), freshnessDays: 2, addedDate: DateHelper.key(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()), usageSuggestion: "优先做燕麦奶昔或法式吐司"),
        InventoryItem(name: "豆腐", quantity: "1", unit: "盒", category: "乳制品", unitPrice: 1.60, threshold: nil, expiryDate: DateHelper.key(for: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()), freshnessDays: 2, addedDate: DateHelper.todayKey, usageSuggestion: "今晚做菌菇豆腐汤"),
        InventoryItem(name: "食用油", quantity: "0.3", unit: "瓶", category: "调料", unitPrice: 7.90, threshold: 0.5, expiryDate: nil, freshnessDays: 0, addedDate: DateHelper.todayKey, usageSuggestion: "下次采购补一瓶大包装"),
        InventoryItem(name: "番茄", quantity: "2", unit: "个", category: "蔬菜", unitPrice: 0.80, threshold: 2, expiryDate: nil, freshnessDays: 5, addedDate: DateHelper.key(for: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date()), usageSuggestion: "做番茄炒蛋或番茄牛腩"),
        InventoryItem(name: "鸡胸肉", quantity: "1", unit: "份", category: "肉类", unitPrice: 4.60, threshold: 1, expiryDate: nil, freshnessDays: 2, addedDate: DateHelper.key(for: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()), usageSuggestion: "可做芦笋鸡胸肉或煎鸡排")
    ]
}

struct BudgetState: Codable {
    var monthlyBudget: Double
    var transactions: [BudgetTransaction]
    var wasteRecords: [WasteRecord]
    var purchaseRecords: [PurchaseRecord]

    static let sample = BudgetState(
        monthlyBudget: 300,
        transactions: [
            BudgetTransaction(amount: 68, note: "周末超市采购", category: "买菜", date: DateHelper.todayKey),
            BudgetTransaction(amount: 16, note: "补充水果", category: "饮料", date: DateHelper.todayKey),
            BudgetTransaction(amount: 24, note: "零食补货", category: "零食", date: DateHelper.key(for: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()))
        ],
        wasteRecords: [
            WasteRecord(itemName: "菠菜", amount: 2.40, date: DateHelper.key(for: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()))
        ]
    )
    
    init(monthlyBudget: Double = 300, transactions: [BudgetTransaction] = [], wasteRecords: [WasteRecord] = [], purchaseRecords: [PurchaseRecord] = []) {
        self.monthlyBudget = monthlyBudget
        self.transactions = transactions
        self.wasteRecords = wasteRecords
        self.purchaseRecords = purchaseRecords
    }

    enum CodingKeys: String, CodingKey {
        case monthlyBudget, transactions, wasteRecords, purchaseRecords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monthlyBudget = try container.decodeIfPresent(Double.self, forKey: .monthlyBudget) ?? 300
        transactions = try container.decodeIfPresent([BudgetTransaction].self, forKey: .transactions) ?? []
        wasteRecords = try container.decodeIfPresent([WasteRecord].self, forKey: .wasteRecords) ?? []
        purchaseRecords = try container.decodeIfPresent([PurchaseRecord].self, forKey: .purchaseRecords) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monthlyBudget, forKey: .monthlyBudget)
        try container.encode(transactions, forKey: .transactions)
        try container.encode(wasteRecords, forKey: .wasteRecords)
        try container.encode(purchaseRecords, forKey: .purchaseRecords)
    }
}

struct BudgetTransaction: Identifiable, Codable {
    let id: UUID
    let amount: Double
    let note: String
    let category: String
    let date: String

    init(id: UUID = UUID(), amount: Double, note: String, category: String, date: String) {
        self.id = id
        self.amount = amount
        self.note = note
        self.category = category
        self.date = date
    }
}

struct PurchaseRecord: Identifiable, Codable {
    let id: UUID
    let date: String
    let totalAmount: Double
    let items: [PurchaseLineItem]

    init(id: UUID = UUID(), date: String, totalAmount: Double, items: [PurchaseLineItem]) {
        self.id = id
        self.date = date
        self.totalAmount = totalAmount
        self.items = items
    }

    var itemCount: Int {
        items.count
    }

    var summaryText: String {
        let names = items.prefix(3).map(\.name).joined(separator: "、")
        guard !names.isEmpty else { return "采购记录" }
        return items.count > 3 ? "\(names) 等\(items.count)项" : names
    }
}

struct PurchaseLineItem: Identifiable, Codable {
    let id: UUID
    /// The checked shopping-list item that produced this line, when checkout is opened from the list.
    /// Kept optional so older purchase records remain decodable.
    let shoppingItemID: UUID?
    var name: String
    var quantity: String
    var unit: String
    var unitPrice: Double
    var category: String

    init(
        id: UUID = UUID(),
        shoppingItemID: UUID? = nil,
        name: String,
        quantity: String,
        unit: String,
        unitPrice: Double,
        category: String
    ) {
        self.id = id
        self.shoppingItemID = shoppingItemID
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.category = category
    }

    var quantityValue: Double {
        max(Double(quantity) ?? 0, 0)
    }

    var totalCost: Double {
        quantityValue * unitPrice
    }
}

struct MealIngredient: Codable, Hashable {
    let name: String
    let quantity: Double
    let unit: String

    init(name: String, quantity: Double, unit: String) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }
}

struct WasteRecord: Identifiable, Codable {
    let id: UUID
    let itemName: String
    let amount: Double
    let date: String

    init(id: UUID = UUID(), itemName: String, amount: Double, date: String) {
        self.id = id
        self.itemName = itemName
        self.amount = amount
        self.date = date
    }
}

struct HydrationEntry: Identifiable, Codable {
    let id: UUID
    var dateKey: String
    var drinkName: String
    var amountML: Int

    init(id: UUID = UUID(), dateKey: String, drinkName: String, amountML: Int) {
        self.id = id
        self.dateKey = dateKey
        self.drinkName = drinkName
        self.amountML = amountML
    }
}

struct HydrationState: Codable {
    var dailyGoalML: Int
    var entries: [HydrationEntry]

    static let sample = HydrationState(
        dailyGoalML: 2000,
        entries: [
            HydrationEntry(dateKey: DateHelper.todayKey, drinkName: "水", amountML: 500),
            HydrationEntry(dateKey: DateHelper.todayKey, drinkName: "咖啡", amountML: 250),
            HydrationEntry(dateKey: DateHelper.todayKey, drinkName: "水", amountML: 500)
        ]
    )

    init(dailyGoalML: Int = 2000, entries: [HydrationEntry] = []) {
        self.dailyGoalML = dailyGoalML
        self.entries = entries
    }

    enum CodingKeys: String, CodingKey {
        case dailyGoalML, entries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dailyGoalML = try container.decodeIfPresent(Int.self, forKey: .dailyGoalML) ?? 2000
        entries = try container.decodeIfPresent([HydrationEntry].self, forKey: .entries) ?? []
    }

    func totalAmount(on dateKey: String) -> Int {
        entries
            .filter { $0.dateKey == dateKey }
            .reduce(0) { $0 + max($1.amountML, 0) }
    }
}

struct RecipeIngredient: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Double
    let unit: String
    let currentQuantity: String
    let shortageQuantity: Double
    let needToBuy: Bool
}

struct AIRecipeResult {
    let dish: String
    let ingredients: [RecipeIngredient]
    let tips: String

    var missingIngredients: [RecipeIngredient] {
        ingredients.filter(\.needToBuy)
    }

    var canCookNow: Bool {
        missingIngredients.isEmpty
    }
}

struct AISuggestion: Identifiable {
    let id = UUID()
    let dish: String
    let ingredients: [RecipeIngredient]
    let reason: String

    var missingIngredients: [RecipeIngredient] {
        ingredients.filter(\.needToBuy)
    }

    var canCookNow: Bool {
        missingIngredients.isEmpty
    }
}

struct ShoppingSyncSummary {
    let addedNames: [String]
    let updatedNames: [String]

    static let empty = ShoppingSyncSummary(addedNames: [], updatedNames: [])

    var affectedNames: [String] {
        var seen = Set<String>()
        return (addedNames + updatedNames).filter { seen.insert($0).inserted }
    }

    var isEmpty: Bool {
        affectedNames.isEmpty
    }
}

struct AlertBundle {
    var expired: [AlertItem]
    var expiringSoon: [AlertItem]
    var lowStock: [AlertItem]
    var notFresh: [AlertItem]

    var totalCount: Int {
        Set((expired + expiringSoon + lowStock + notFresh).map(\.id)).count
    }
}

struct AlertItem: Identifiable {
    let id: UUID
    let label: String
}

struct InventoryStatusInfo {
    enum Level {
        case normal
        case warning
        case danger
    }

    let text: String
    let color: Color
    let level: Level
}

struct MealCellEditingState: Identifiable {
    let id = UUID()
    let dateKey: String
    let mealSlot: MealSlot
    let value: String
}

struct ShoppingItemForm {
    var name = ""
    var quantity = ""
    var unit = "个"
    var category = "蔬菜"
    var day = ""
    var estimatedUnitPrice = ""
}

struct InventoryForm {
    var name = ""
    var quantity = ""
    var unit = "个"
    var category = "蔬菜"
    var unitPrice = ""
    var threshold = ""
    var expiryDate: Date?
    var freshnessDays = ""
}

struct BudgetEntryForm {
    var amount = ""
    var note = ""
    var category = "买菜"
}

extension ShoppingItem {
    var quantityValue: Double {
        let rawValue = Double(quantity) ?? 1
        return rawValue > 0 ? rawValue : 1
    }

    var effectiveUnitPrice: Double {
        estimatedUnitPrice ?? KitchenData.estimatedUnitPrice(for: name, category: category, unit: unit)
    }

    var estimatedTotalCost: Double {
        effectiveUnitPrice * quantityValue
    }
}

extension RecipeIngredient {
    var purchaseQuantity: Double {
        let amount = shortageQuantity > 0 ? shortageQuantity : quantity
        return amount > 0 ? amount : quantity
    }

    var purchaseQuantityText: String {
        purchaseQuantity.cleanString
    }
}

extension InventoryItem {
    var quantityValue: Double {
        max(Double(quantity) ?? 0, 0)
    }

    var effectiveUnitPrice: Double {
        unitPrice ?? KitchenData.estimatedUnitPrice(for: name, category: category, unit: unit)
    }

    var estimatedRemainingValue: Double {
        effectiveUnitPrice * quantityValue
    }
}
