import XCTest
@testable import Kitchen_Manager

@MainActor
final class KitchenManagerTests: XCTestCase {
    func testCleanStringPreservesMeaningfulFractionalDigits() {
        XCTAssertEqual(1.25.cleanString, "1.25")
        XCTAssertEqual(0.05.cleanString, "0.05")
        XCTAssertEqual(2.0.cleanString, "2")
    }

    func testSundayUsesSundayLabel() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25))!

        XCTAssertEqual(DateHelper.weekdayName(for: sunday), "周日")
    }

    func testCheckoutRemovesOnlySettledShoppingRows() {
        let store = KitchenStore(inMemory: true)
        let settled = ShoppingItem(
            name: "番茄",
            quantity: "1.25",
            unit: "个",
            category: "蔬菜",
            day: "",
            isChecked: true,
            estimatedUnitPrice: 0.8
        )
        let untouchedChecked = ShoppingItem(
            name: "鸡蛋",
            quantity: "2",
            unit: "个",
            category: "乳制品",
            day: "",
            isChecked: true,
            estimatedUnitPrice: 0.35
        )
        let pending = ShoppingItem(
            name: "生抽",
            quantity: "1",
            unit: "瓶",
            category: "调料",
            day: "",
            isChecked: false,
            estimatedUnitPrice: 3.8
        )
        store.shoppingState = ShoppingState(items: [settled, untouchedChecked, pending])
        store.inventoryItems = []

        let didCheckout = store.checkoutShoppingTrip(lineItems: [
            PurchaseLineItem(
                shoppingItemID: settled.id,
                name: settled.name,
                quantity: settled.quantity,
                unit: settled.unit,
                unitPrice: settled.effectiveUnitPrice,
                category: settled.category
            )
        ])

        XCTAssertTrue(didCheckout)
        XCTAssertNil(store.shoppingState.items.first(where: { $0.id == settled.id }))
        XCTAssertNotNil(store.shoppingState.items.first(where: { $0.id == untouchedChecked.id }))
        XCTAssertNotNil(store.shoppingState.items.first(where: { $0.id == pending.id }))
        XCTAssertEqual(store.inventoryItems.first?.quantity, "1.25")
    }

    func testInvalidCheckoutLeavesShoppingRowsUntouched() {
        let store = KitchenStore(inMemory: true)
        let item = ShoppingItem(
            name: "番茄",
            quantity: "1",
            unit: "个",
            category: "蔬菜",
            day: "",
            isChecked: true,
            estimatedUnitPrice: 0.8
        )
        store.shoppingState = ShoppingState(items: [item])

        let didCheckout = store.checkoutShoppingTrip(lineItems: [
            PurchaseLineItem(
                shoppingItemID: item.id,
                name: item.name,
                quantity: "0",
                unit: item.unit,
                unitPrice: item.effectiveUnitPrice,
                category: item.category
            )
        ])

        XCTAssertFalse(didCheckout)
        XCTAssertEqual(store.shoppingState.items.map(\.id), [item.id])
        XCTAssertTrue(store.budgetState.purchaseRecords.isEmpty)
    }

    func testCompletingRecipeMealDeductsInventoryOnce() {
        let store = KitchenStore(inMemory: true)
        let dateKey = DateHelper.todayKey
        store.inventoryItems = [
            InventoryItem(
                name: "番茄",
                quantity: "2",
                unit: "个",
                category: "蔬菜",
                unitPrice: 0.8,
                threshold: nil,
                expiryDate: nil,
                freshnessDays: 0,
                addedDate: dateKey,
                usageSuggestion: ""
            )
        ]
        store.mealPlans = [dateKey: [.dinner: "番茄炒蛋"]]
        store.mealIngredients = [dateKey: [
            .dinner: [MealIngredient(name: "番茄", quantity: 0.5, unit: "个")]
        ]]

        XCTAssertTrue(store.completeMeal(dateKey: dateKey, slot: .dinner))
        XCTAssertEqual(store.inventoryItems.first?.quantity, "1.5")
        XCTAssertEqual(store.mealPlans[dateKey]?[.dinner], "✅ 番茄炒蛋")

        XCTAssertFalse(store.completeMeal(dateKey: dateKey, slot: .dinner))
        XCTAssertEqual(store.inventoryItems.first?.quantity, "1.5")
    }

    func testShoppingGroupsKeepRemovedAndOutOfWeekDates() {
        let old = shoppingItem("旧清单", day: "2026-10-31")
        let future = shoppingItem("下周清单", day: "2026-11-10")
        let unassigned = shoppingItem("未分配", day: "")
        var state = ShoppingState(shopDays: ["2026-11-02"], items: [future, unassigned, old], fixedShopWeekdays: [6])
        let now = DateHelper.date(from: "2026-11-02")!
        let week = DateHelper.weekDates(from: DateHelper.weekStart(for: now))
        XCTAssertFalse(state.resolvedShopDays(for: week).contains(old.day))
        XCTAssertFalse(state.resolvedShopDays(for: week).contains(future.day))
        XCTAssertEqual(state.itemGroups().map(\.day), [old.day, future.day, ""])
        state.shopDays.removeAll()
        state.fixedShopWeekdays.removeAll()
        XCTAssertEqual(state.itemGroups().flatMap(\.items).map(\.id), [old.id, future.id, unassigned.id])
        XCTAssertEqual(state.itemGroups().first?.title(today: "2026-11-02"), "逾期 · 2026-10-31")
    }

    func testShoppingGroupsRespectCategoryWithoutDroppingCheckedRows() {
        let vegetable = shoppingItem("番茄", day: "2026-11-02", checked: true)
        let drink = ShoppingItem(name: "牛奶", quantity: "1", unit: "瓶", category: "饮料", day: "", isChecked: false)
        let state = ShoppingState(items: [vegetable, drink])
        XCTAssertEqual(state.itemGroups(category: "蔬菜").flatMap(\.items).map(\.id), [vegetable.id])
        XCTAssertTrue(state.itemGroups(category: "海鲜").isEmpty)
    }

    func testCheckingAndSettlingPreserveProjectedBudget() {
        let store = KitchenStore(inMemory: true)
        store.budgetState = BudgetState(monthlyBudget: 100)
        let first = shoppingItem("番茄", day: "", price: 10)
        let second = shoppingItem("土豆", day: "", price: 5)
        store.shoppingState = ShoppingState(items: [first, second])
        XCTAssertEqual(store.projectedBudgetRemaining, 85)
        store.shoppingState.items[0].isChecked = true
        XCTAssertEqual(store.pendingShoppingCount, 1)
        XCTAssertEqual(store.pendingShoppingEstimate, 15)
        XCTAssertEqual(store.projectedBudgetRemaining, 85)
        XCTAssertTrue(store.checkoutShoppingTrip(lineItems: [
            PurchaseLineItem(shoppingItemID: first.id, name: first.name, quantity: "1", unit: first.unit,
                             unitPrice: 10, category: first.category)
        ]))
        XCTAssertEqual(store.currentMonthSpent, 10)
        XCTAssertEqual(store.pendingShoppingEstimate, 5)
        XCTAssertEqual(store.projectedBudgetRemaining, 85)
    }

    func testLowStockIsVisibleDespiteDistantExpiryAndFreshness() {
        let now = DateHelper.date(from: "2026-11-02")!
        let item = inventoryItem(expiry: "2026-12-01", freshness: 10, added: "2026-11-01", threshold: 2)
        let insight = AlertEngine.insight(for: item, now: now)
        XCTAssertEqual(insight.status?.text, "库存不足")
        XCTAssertEqual(insight.focus, .upcoming)
        XCTAssertEqual(AlertEngine.compute(inventory: [item], now: now).lowStock.map(\.id), [item.id])
    }

    func testFreshnessIsVisibleDespiteDistantExpiry() {
        let now = DateHelper.date(from: "2026-11-02")!
        let stale = inventoryItem(expiry: "2026-12-01", freshness: 2, added: "2026-10-28")
        let soon = inventoryItem(expiry: "2026-12-01", freshness: 3, added: "2026-11-01")
        XCTAssertEqual(AlertEngine.insight(for: stale, now: now).focus, .critical)
        XCTAssertEqual(AlertEngine.insight(for: stale, now: now).status?.text, "不新鲜")
        XCTAssertEqual(AlertEngine.insight(for: soon, now: now).focus, .upcoming)
        let bundle = AlertEngine.compute(inventory: [stale, soon], now: now)
        XCTAssertEqual(bundle.notFresh.map(\.id), [stale.id])
        XCTAssertEqual(bundle.expiringSoon.map(\.id), [soon.id])
    }

    func testAlertCountAndInventoryGroupingAgreeForMultipleIssues() {
        let now = DateHelper.date(from: "2026-11-02")!
        let expired = inventoryItem(expiry: "2026-11-01", freshness: 1, added: "2026-10-28", threshold: 2)
        let today = inventoryItem(expiry: "2026-11-02", freshness: 0, added: "2026-11-01")
        let healthy = inventoryItem(expiry: "2026-12-01", freshness: 10, added: "2026-11-01")
        let items = [expired, today, healthy]
        let bundle = AlertEngine.compute(inventory: items, now: now)
        XCTAssertEqual(bundle.expired.count, 1)
        XCTAssertEqual(bundle.lowStock.count, 1)
        XCTAssertEqual(bundle.totalCount, 2)
        XCTAssertEqual(items.filter { AlertEngine.insight(for: $0, now: now).focus != nil }.count, bundle.totalCount)
        XCTAssertEqual(AlertEngine.insight(for: expired, now: now).status?.text, "已过期 1 天")
        XCTAssertEqual(AlertEngine.insight(for: today, now: now).status?.text, "今天到期")
        XCTAssertNil(AlertEngine.insight(for: healthy, now: now).focus)
    }

    func testMealEditorUpdatesOnlySelectedDateAndSlot() {
        let store = KitchenStore(inMemory: true)
        let date = "2026-11-02"
        store.mealPlans = [date: [.breakfast: "燕麦", .dinner: "汤"], "2026-11-03": [.dinner: "面"]]
        store.mealIngredients = [date: [.dinner: [MealIngredient(name: "豆腐", quantity: 1, unit: "块")]]]
        store.updateMeal("  炒饭  ", dateKey: date, slot: .dinner)
        XCTAssertEqual(store.mealPlans[date]?[.dinner], "炒饭")
        XCTAssertEqual(store.mealPlans[date]?[.breakfast], "燕麦")
        XCTAssertEqual(store.mealPlans["2026-11-03"]?[.dinner], "面")
        XCTAssertNil(store.mealIngredients[date]?[.dinner])
        store.updateMeal(" ", dateKey: date, slot: .dinner)
        XCTAssertNil(store.mealPlans[date]?[.dinner])
        XCTAssertEqual(store.mealPlans[date]?[.breakfast], "燕麦")
    }

    private func shoppingItem(_ name: String, day: String, checked: Bool = false, price: Double = 1) -> ShoppingItem {
        ShoppingItem(name: name, quantity: "1", unit: "个", category: "蔬菜", day: day,
                     isChecked: checked, estimatedUnitPrice: price)
    }

    private func inventoryItem(expiry: String?, freshness: Int, added: String, threshold: Double? = nil) -> InventoryItem {
        InventoryItem(name: "食材", quantity: "1", unit: "个", category: "蔬菜", unitPrice: 1,
                      threshold: threshold, expiryDate: expiry, freshnessDays: freshness,
                      addedDate: added, usageSuggestion: "")
    }
}
