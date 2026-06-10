import SwiftUI
import Security

@Observable
final class KitchenStore {
    var inventoryItems: [InventoryItem] = [] {
        didSet { scheduleSave() }
    }
    
    var shoppingState: ShoppingState = ShoppingState() {
        didSet { scheduleSave() }
    }
    
    var mealPlans: [String: [MealSlot: String]] = [:] {
        didSet { scheduleSave() }
    }
    
    var budgetState: BudgetState = BudgetState() {
        didSet { scheduleSave() }
    }

    var hydrationState: HydrationState = HydrationState() {
        didSet { scheduleSave() }
    }
    
    var aiApiKey: String = "" {
        didSet {
            if !KeychainSecretStore.saveAPIKey(aiApiKey) {
                print("Failed to save AI API key to Keychain.")
            }
        }
    }
    
    var aiBaseURL: String = "https://api.openai.com/v1" {
        didSet { scheduleSave() }
    }
    
    var aiModel: String = "gpt-4o-mini" {
        didSet { scheduleSave() }
    }
    
    var toastMessage: String?
    var toastKind: ToastKind = .info

    // 提醒相关计算属性
    var alerts: AlertBundle {
        AlertEngine.compute(inventory: inventoryItems)
    }

    var alertCount: Int {
        alerts.totalCount
    }

    var pendingShoppingCount: Int {
        shoppingState.items.filter { !$0.isChecked }.count
    }

    var pendingShoppingEstimate: Double {
        shoppingState.items
            .filter { !$0.isChecked }
            .reduce(0) { $0 + $1.estimatedTotalCost }
    }

    func monthSpent(for monthKey: String) -> Double {
        budgetState.transactions.reduce(0) { partial, tx in
            guard let date = DateHelper.date(from: tx.date),
                  DateHelper.monthKey(for: date) == monthKey else { return partial }
            return partial + tx.amount
        }
    }

    var currentMonthSpent: Double {
        monthSpent(for: DateHelper.monthKey(for: Date()))
    }

    var projectedBudgetRemaining: Double {
        budgetState.monthlyBudget - currentMonthSpent - pendingShoppingEstimate
    }

    var todayHydrationAmountML: Int {
        hydrationState.totalAmount(on: DateHelper.todayKey)
    }

    var dailyWaterGoalML: Int {
        hydrationState.dailyGoalML
    }

    private var saveTask: Task<Void, Never>?
    private let fileURL: URL

    private struct PurchaseBucket {
        let name: String
        let unit: String
        let category: String
        let unitPrice: Double
        let quantity: Double
    }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("kitchen_data.json")
        load()
    }
    
    func showToast(_ message: String, kind: ToastKind = .info) {
        withAnimation {
            toastMessage = message
            toastKind = kind
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            guard self.toastMessage == message else { return }
            withAnimation {
                self.toastMessage = nil
            }
        }
    }

    func assignMeal(_ dish: String, dateKey: String, slot: MealSlot) {
        let title = dish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        var day = mealPlans[dateKey] ?? [:]
        day[slot] = title
        mealPlans[dateKey] = day
    }

    func addHydration(amountML: Int = 250, drinkName: String = "水", dateKey: String = DateHelper.todayKey) {
        guard amountML > 0 else { return }

        var state = hydrationState
        state.entries.append(
            HydrationEntry(
                dateKey: dateKey,
                drinkName: drinkName,
                amountML: amountML
            )
        )
        hydrationState = state
        showToast("已记录 \(amountML)ml \(drinkName)", kind: .success)
    }

    func preferredShoppingDay(for mealDate: String) -> String {
        guard !shoppingState.shopDays.isEmpty else { return mealDate }
        if shoppingState.shopDays.contains(mealDate) {
            return mealDate
        }

        let sortedDays = shoppingState.shopDays.sorted()
        if let nextDay = sortedDays.first(where: { $0 >= mealDate }) {
            return nextDay
        }
        return sortedDays.last ?? mealDate
    }

    @discardableResult
    func syncMissingIngredientsToShoppingList(_ ingredients: [RecipeIngredient], preferredDay: String = "") -> ShoppingSyncSummary {
        let missingItems = ingredients.filter(\.needToBuy)
        guard !missingItems.isEmpty else { return .empty }

        var addedNames: [String] = []
        var updatedNames: [String] = []

        for ingredient in missingItems {
            let purchaseQuantity = ingredient.purchaseQuantity
            guard purchaseQuantity > 0 else { continue }

            let category = KitchenData.categoryGuess(for: ingredient.name)
            let estimatedUnitPrice = KitchenData.estimatedUnitPrice(
                for: ingredient.name,
                category: category,
                unit: ingredient.unit
            )

            if let index = shoppingState.items.firstIndex(where: {
                !$0.isChecked &&
                $0.unit == ingredient.unit &&
                KitchenData.isLikelySameIngredient($0.name, ingredient.name)
            }) {
                let currentQuantity = Double(shoppingState.items[index].quantity) ?? 0
                shoppingState.items[index].quantity = (currentQuantity + purchaseQuantity).cleanString

                if shoppingState.items[index].day.isEmpty && !preferredDay.isEmpty {
                    shoppingState.items[index].day = preferredDay
                }
                if shoppingState.items[index].estimatedUnitPrice == nil {
                    shoppingState.items[index].estimatedUnitPrice = estimatedUnitPrice
                }
                if shoppingState.items[index].category == "其他" {
                    shoppingState.items[index].category = category
                }

                updatedNames.append(ingredient.name)
            } else {
                shoppingState.items.append(
                    ShoppingItem(
                        name: ingredient.name,
                        quantity: purchaseQuantity.cleanString,
                        unit: ingredient.unit,
                        category: category,
                        day: preferredDay,
                        isChecked: false,
                        estimatedUnitPrice: estimatedUnitPrice
                    )
                )
                addedNames.append(ingredient.name)
            }
        }

        return ShoppingSyncSummary(addedNames: addedNames, updatedNames: updatedNames)
    }

    func recordWaste(for item: InventoryItem, dateKey: String = DateHelper.todayKey) {
        let estimatedAmount = item.estimatedRemainingValue
        guard estimatedAmount > 0 else { return }

        budgetState.wasteRecords.append(
            WasteRecord(
                itemName: item.name,
                amount: estimatedAmount,
                date: dateKey
            )
        )
    }

    /// When a shopping item is checked off, automatically add/merge into inventory
    func completeShoppingItem(_ item: ShoppingItem) {
        guard !item.name.isEmpty else { return }

        if let index = inventoryItems.firstIndex(where: {
            KitchenData.isLikelySameIngredient($0.name, item.name) && $0.unit == item.unit
        }) {
            // Merge quantity into existing inventory item
            let current = Double(inventoryItems[index].quantity) ?? 0
            let added = Double(item.quantity) ?? 0
            inventoryItems[index].quantity = (current + added).cleanString
        } else {
            // Create new inventory item
            let category = item.category == "其他" ? KitchenData.categoryGuess(for: item.name) : item.category
            let freshness = KitchenData.defaultFreshness[category] ?? 0
            inventoryItems.append(
                InventoryItem(
                    name: item.name,
                    quantity: item.quantity.isEmpty ? "1" : item.quantity,
                    unit: item.unit,
                    category: category,
                    unitPrice: item.estimatedUnitPrice,
                    threshold: nil,
                    expiryDate: nil,
                    freshnessDays: freshness,
                    addedDate: DateHelper.todayKey,
                    usageSuggestion: InventoryRecommendation.suggestion(for: item.name, category: category)
                )
            )
        }
    }

    /// When a meal is marked as eaten, deduct recipe ingredients from inventory
    func completeMeal(dateKey: String, slot: MealSlot) {
        guard let meals = mealPlans[dateKey], let dish = meals[slot], !dish.isEmpty else { return }

        // Mark as completed by prefixing with ✅
        guard !dish.hasPrefix("✅") else { return }
        var day = mealPlans[dateKey] ?? [:]
        day[slot] = "✅ " + dish
        mealPlans[dateKey] = day
    }

    /// Checkout: finalize a shopping trip with editable line items, sync to inventory & budget
    func checkoutShoppingTrip(lineItems: [PurchaseLineItem]) {
        let normalizedItems = normalizedPurchaseLineItems(lineItems)
        guard !normalizedItems.isEmpty else { return }

        let record = PurchaseRecord(
            id: UUID(),
            date: DateHelper.todayKey,
            totalAmount: normalizedItems.reduce(0) { $0 + $1.totalCost },
            items: normalizedItems
        )
        budgetState.purchaseRecords.append(record)
        upsertPurchaseTransaction(for: record)
        syncInventoryForPurchaseChange(from: [], to: record.items)

        // Remove checked items from shopping list after checkout succeeds.
        shoppingState.items.removeAll { $0.isChecked }
    }

    @discardableResult
    func updatePurchaseRecord(_ record: PurchaseRecord) -> Bool {
        guard let index = budgetState.purchaseRecords.firstIndex(where: { $0.id == record.id }) else {
            return false
        }

        let normalizedItems = normalizedPurchaseLineItems(record.items)
        guard !normalizedItems.isEmpty else { return false }

        let previous = budgetState.purchaseRecords[index]
        let updated = PurchaseRecord(
            id: previous.id,
            date: record.date,
            totalAmount: normalizedItems.reduce(0) { $0 + $1.totalCost },
            items: normalizedItems
        )

        budgetState.purchaseRecords[index] = updated
        upsertPurchaseTransaction(for: updated)
        syncInventoryForPurchaseChange(from: previous.items, to: updated.items)
        return true
    }

    func deletePurchaseRecord(_ record: PurchaseRecord) {
        guard let index = budgetState.purchaseRecords.firstIndex(where: { $0.id == record.id }) else {
            return
        }

        let removed = budgetState.purchaseRecords.remove(at: index)
        removePurchaseTransaction(for: removed)
        syncInventoryForPurchaseChange(from: removed.items, to: [])
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(0.5))
            if !Task.isCancelled {
                save()
            }
        }
    }

    private func save() {
        let dataToSave = SerializedData(
            inventoryItems: inventoryItems,
            shoppingState: shoppingState,
            mealPlans: mealPlans,
            budgetState: budgetState,
            hydrationState: hydrationState,
            aiBaseURL: aiBaseURL,
            aiModel: aiModel
        )
        do {
            let data = try JSONEncoder().encode(dataToSave)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save data: \(error)")
        }
    }

    private func load() {
        aiApiKey = KeychainSecretStore.apiKey()

        guard let data = try? Data(contentsOf: fileURL) else {
            // 第一次启动，加载示例数据
            inventoryItems = InventoryItem.samples
            shoppingState = ShoppingState.samples
            budgetState = BudgetState.sample
            hydrationState = HydrationState.sample
            mealPlans = [
                DateHelper.todayKey: [
                    .breakfast: "燕麦牛奶杯",
                    .lunch: "番茄鸡胸肉意面",
                    .dinner: "菌菇豆腐汤",
                    .drinks: "柠檬红茶"
                ],
                DateHelper.key(for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()): [
                    .breakfast: "鸡蛋三明治",
                    .dinner: "番茄炒蛋"
                ]
            ]
            return
        }

        do {
            let savedData = try JSONDecoder().decode(SerializedData.self, from: data)
            inventoryItems = savedData.inventoryItems
            shoppingState = savedData.shoppingState
            mealPlans = savedData.mealPlans
            budgetState = savedData.budgetState
            hydrationState = savedData.hydrationState ?? HydrationState()
            migratePurchaseTransactionsIfNeeded()
            if let legacyAPIKey = savedData.legacyAiApiKey,
               !legacyAPIKey.isEmpty,
               KeychainSecretStore.apiKey().isEmpty {
                _ = KeychainSecretStore.saveAPIKey(legacyAPIKey)
            }
            aiApiKey = KeychainSecretStore.apiKey()
            aiBaseURL = savedData.aiBaseURL ?? "https://api.openai.com/v1"
            aiModel = savedData.aiModel ?? "gpt-4o-mini"
        } catch {
            print("Failed to load data: \(error)")
        }
    }

    private func normalizedPurchaseLineItems(_ lineItems: [PurchaseLineItem]) -> [PurchaseLineItem] {
        lineItems.compactMap { item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }

            let quantity = item.quantityValue
            guard quantity > 0 else { return nil }

            let category = item.category.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedCategory = category.isEmpty ? KitchenData.categoryGuess(for: name) : category
            let unit = item.unit.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedUnit = unit.isEmpty ? KitchenData.unitGuess(for: name, category: resolvedCategory) : unit
            let unitPrice = max(item.unitPrice, 0)

            return PurchaseLineItem(
                id: item.id,
                name: name,
                quantity: quantity.cleanString,
                unit: resolvedUnit,
                unitPrice: unitPrice,
                category: resolvedCategory
            )
        }
    }

    private func syncInventoryForPurchaseChange(from oldItems: [PurchaseLineItem], to newItems: [PurchaseLineItem]) {
        let oldBuckets = purchaseBuckets(from: oldItems)
        let newBuckets = purchaseBuckets(from: newItems)
        let keys = Set(oldBuckets.keys).union(newBuckets.keys)

        for key in keys {
            let oldBucket = oldBuckets[key]
            let newBucket = newBuckets[key]
            let delta = (newBucket?.quantity ?? 0) - (oldBucket?.quantity ?? 0)

            if let bucket = newBucket ?? oldBucket {
                if delta != 0 {
                    adjustInventory(using: bucket, deltaQuantity: delta)
                } else if let newBucket {
                    updateInventoryMetadata(using: newBucket)
                }
            }
        }
    }

    private func purchaseBuckets(from items: [PurchaseLineItem]) -> [String: PurchaseBucket] {
        var buckets: [String: PurchaseBucket] = [:]

        for item in items {
            let key = purchaseBucketKey(name: item.name, unit: item.unit)
            let existingQuantity = buckets[key]?.quantity ?? 0
            buckets[key] = PurchaseBucket(
                name: item.name,
                unit: item.unit,
                category: item.category,
                unitPrice: item.unitPrice,
                quantity: existingQuantity + item.quantityValue
            )
        }

        return buckets
    }

    private func purchaseBucketKey(name: String, unit: String) -> String {
        let normalizedName = KitchenData.normalizedIngredientName(name)
        let normalizedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedName)|\(normalizedUnit)"
    }

    private func adjustInventory(using bucket: PurchaseBucket, deltaQuantity: Double) {
        guard !bucket.name.isEmpty else { return }

        if let index = inventoryItems.firstIndex(where: {
            KitchenData.isLikelySameIngredient($0.name, bucket.name) && $0.unit == bucket.unit
        }) {
            let current = Double(inventoryItems[index].quantity) ?? 0
            let next = current + deltaQuantity

            if next <= 0 {
                inventoryItems.remove(at: index)
                return
            }

            inventoryItems[index].quantity = next.cleanString
            if bucket.category != "其他" {
                inventoryItems[index].category = bucket.category
            }
            if bucket.unitPrice > 0 {
                inventoryItems[index].unitPrice = bucket.unitPrice
            }
        } else if deltaQuantity > 0 {
            let category = bucket.category == "其他" ? KitchenData.categoryGuess(for: bucket.name) : bucket.category
            let freshness = KitchenData.defaultFreshness[category] ?? 0
            inventoryItems.append(
                InventoryItem(
                    name: bucket.name,
                    quantity: deltaQuantity.cleanString,
                    unit: bucket.unit,
                    category: category,
                    unitPrice: bucket.unitPrice > 0 ? bucket.unitPrice : nil,
                    threshold: nil,
                    expiryDate: nil,
                    freshnessDays: freshness,
                    addedDate: DateHelper.todayKey,
                    usageSuggestion: InventoryRecommendation.suggestion(for: bucket.name, category: category)
                )
            )
        }
    }

    private func updateInventoryMetadata(using bucket: PurchaseBucket) {
        guard let index = inventoryItems.firstIndex(where: {
            KitchenData.isLikelySameIngredient($0.name, bucket.name) && $0.unit == bucket.unit
        }) else {
            return
        }

        if bucket.category != "其他" {
            inventoryItems[index].category = bucket.category
        }
        if bucket.unitPrice > 0 {
            inventoryItems[index].unitPrice = bucket.unitPrice
        }
    }

    private func upsertPurchaseTransaction(for record: PurchaseRecord) {
        let transaction = BudgetTransaction(
            id: record.id,
            amount: record.totalAmount,
            note: record.summaryText,
            category: "买菜",
            date: record.date
        )

        if let index = budgetState.transactions.firstIndex(where: { $0.id == record.id }) {
            budgetState.transactions[index] = transaction
        } else if let legacyIndex = legacyPurchaseTransactionIndex(for: record, in: budgetState.transactions) {
            budgetState.transactions[legacyIndex] = transaction
        } else {
            budgetState.transactions.append(transaction)
        }
    }

    private func removePurchaseTransaction(for record: PurchaseRecord) {
        if let index = budgetState.transactions.firstIndex(where: { $0.id == record.id }) {
            budgetState.transactions.remove(at: index)
        } else if let legacyIndex = legacyPurchaseTransactionIndex(for: record, in: budgetState.transactions) {
            budgetState.transactions.remove(at: legacyIndex)
        }
    }

    private func migratePurchaseTransactionsIfNeeded() {
        guard !budgetState.purchaseRecords.isEmpty, !budgetState.transactions.isEmpty else { return }

        var migratedTransactions = budgetState.transactions
        var usedTransactionIDs = Set<UUID>()
        var didChange = false

        for record in budgetState.purchaseRecords {
            if migratedTransactions.contains(where: { $0.id == record.id }) {
                usedTransactionIDs.insert(record.id)
                continue
            }

            if let index = legacyPurchaseTransactionIndex(
                for: record,
                in: migratedTransactions,
                excluding: usedTransactionIDs
            ) {
                let legacyTransaction = migratedTransactions[index]
                migratedTransactions[index] = BudgetTransaction(
                    id: record.id,
                    amount: legacyTransaction.amount,
                    note: legacyTransaction.note,
                    category: legacyTransaction.category,
                    date: legacyTransaction.date
                )
                usedTransactionIDs.insert(record.id)
                didChange = true
            }
        }

        if didChange {
            budgetState.transactions = migratedTransactions
        }
    }

    private func legacyPurchaseTransactionIndex(
        for record: PurchaseRecord,
        in transactions: [BudgetTransaction],
        excluding excludedIDs: Set<UUID> = []
    ) -> Int? {
        let previewNames = record.items.prefix(3).map(\.name)

        let candidates = transactions.enumerated().filter {
            let transaction = $0.element
            guard transaction.category == "买菜" else { return false }
            guard !excludedIDs.contains(transaction.id) else { return false }
            guard transaction.date == record.date else { return false }
            return abs(transaction.amount - record.totalAmount) < 0.01
        }

        if let namedMatch = candidates.first(where: {
            let transaction = $0.element
            return previewNames.contains(where: { !$0.isEmpty && transaction.note.contains($0) })
        }) {
            return namedMatch.offset
        }

        return candidates.first?.offset
    }

    private struct SerializedData: Codable {
        let inventoryItems: [InventoryItem]
        let shoppingState: ShoppingState
        let mealPlans: [String: [MealSlot: String]]
        let budgetState: BudgetState
        var hydrationState: HydrationState?
        var legacyAiApiKey: String?
        var aiBaseURL: String?
        var aiModel: String?

        enum CodingKeys: String, CodingKey {
            case inventoryItems
            case shoppingState
            case mealPlans
            case budgetState
            case hydrationState
            case legacyAiApiKey = "aiApiKey"
            case aiBaseURL
            case aiModel
        }

        init(
            inventoryItems: [InventoryItem],
            shoppingState: ShoppingState,
            mealPlans: [String: [MealSlot: String]],
            budgetState: BudgetState,
            hydrationState: HydrationState?,
            aiBaseURL: String?,
            aiModel: String?
        ) {
            self.inventoryItems = inventoryItems
            self.shoppingState = shoppingState
            self.mealPlans = mealPlans
            self.budgetState = budgetState
            self.hydrationState = hydrationState
            self.legacyAiApiKey = nil
            self.aiBaseURL = aiBaseURL
            self.aiModel = aiModel
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            inventoryItems = try container.decode([InventoryItem].self, forKey: .inventoryItems)
            shoppingState = try container.decode(ShoppingState.self, forKey: .shoppingState)
            mealPlans = try container.decode([String: [MealSlot: String]].self, forKey: .mealPlans)
            budgetState = try container.decode(BudgetState.self, forKey: .budgetState)
            hydrationState = try container.decodeIfPresent(HydrationState.self, forKey: .hydrationState)
            legacyAiApiKey = try container.decodeIfPresent(String.self, forKey: .legacyAiApiKey)
            aiBaseURL = try container.decodeIfPresent(String.self, forKey: .aiBaseURL)
            aiModel = try container.decodeIfPresent(String.self, forKey: .aiModel)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(inventoryItems, forKey: .inventoryItems)
            try container.encode(shoppingState, forKey: .shoppingState)
            try container.encode(mealPlans, forKey: .mealPlans)
            try container.encode(budgetState, forKey: .budgetState)
            try container.encodeIfPresent(hydrationState, forKey: .hydrationState)
            try container.encodeIfPresent(aiBaseURL, forKey: .aiBaseURL)
            try container.encodeIfPresent(aiModel, forKey: .aiModel)
        }
    }
}

private enum KeychainSecretStore {
    private static let service = "com.kitchen-manager.ai"
    private static let apiKeyAccount = "ai-api-key"

    static func apiKey() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }

        return value
    }

    static func saveAPIKey(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return deleteAPIKey()
        }

        let encoded = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]

        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: encoded] as CFDictionary
        )

        if updateStatus == errSecSuccess {
            return true
        }

        guard updateStatus == errSecItemNotFound else {
            return false
        }

        var attributes = query
        attributes[kSecValueData as String] = encoded
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    private static func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
