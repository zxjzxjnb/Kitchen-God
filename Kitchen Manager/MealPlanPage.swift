import SwiftUI

struct MealPlanPage: View {
    @Environment(KitchenStore.self) private var store

    @State private var weekStart = DateHelper.weekStart(for: Date())
    @State private var focusedDateKey = DateHelper.todayKey
    @State private var editingCell: MealCellEditingState?

    private var weekDates: [Date] {
        DateHelper.weekDates(from: weekStart)
    }

    private var weekLabel: String {
        guard let last = weekDates.last else { return "" }
        return "\(DateHelper.monthDayString(weekStart)) - \(DateHelper.monthDayString(last))"
    }

    private var plannedCount: Int {
        weekDates.reduce(0) { total, date in
            let meals = store.mealPlans[DateHelper.key(for: date)] ?? [:]
            return total + meals.values.filter { !$0.isEmpty }.count
        }
    }

    private var focusedDate: Date {
        DateHelper.date(from: focusedDateKey) ?? weekStart
    }

    private var focusedMeals: [MealSlot: String] {
        store.mealPlans[focusedDateKey] ?? [:]
    }

    private var focusedMealCount: Int {
        focusedMeals.values.filter { !$0.isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(plannedCount == 0 ? "先定今天吃什么。" : "本周已安排 \(plannedCount) 项。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    AIChefPanel(planDate: $focusedDateKey, weekDates: weekDates)
                        .padding(.horizontal)

                    // Week planner
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("本周安排")
                                    .font(.headline)
                                Text("\(weekLabel) · \(plannedCount) 项")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("今天") { showCurrentWeek() }
                                .font(.subheadline.weight(.medium))

                            Button { moveWeek(by: -7) } label: {
                                Image(systemName: "chevron.backward")
                            }
                            Button { moveWeek(by: 7) } label: {
                                Image(systemName: "chevron.forward")
                            }
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], spacing: 8) {
                            ForEach(weekDates, id: \.self) { date in
                                let dateKey = DateHelper.key(for: date)
                                CompactWeekDayButton(
                                    weekday: DateHelper.weekdayName(for: date),
                                    dayText: DateHelper.monthDayString(date),
                                    mealCount: (store.mealPlans[dateKey] ?? [:]).values.filter { !$0.isEmpty }.count,
                                    isSelected: focusedDateKey == dateKey,
                                    isToday: dateKey == DateHelper.todayKey
                                ) {
                                    focusedDateKey = dateKey
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(DateHelper.weekdayName(for: focusedDate)) \(DateHelper.monthDayString(focusedDate))")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(focusedMealCount)/\(MealSlot.allCases.count)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(MealSlot.allCases) { slot in
                                CompactMealSlotRow(
                                    slot: slot,
                                    value: focusedMeals[slot],
                                    isToday: focusedDateKey == DateHelper.todayKey,
                                    action: {
                                        editingCell = MealCellEditingState(
                                            dateKey: focusedDateKey,
                                            mealSlot: slot,
                                            value: focusedMeals[slot] ?? ""
                                        )
                                    },
                                    onComplete: {
                                        store.completeMeal(dateKey: focusedDateKey, slot: slot)
                                        store.showToast("\(slot.title) 已完成")
                                    }
                                )
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            .background(KitchenTheme.background)
            .navigationTitle("菜单")
            .onAppear { syncFocusedDateIfNeeded() }
            .sheet(item: $editingCell) { cell in
                MealEditSheet(
                    state: cell,
                    onSave: { updatedValue in
                        var day = store.mealPlans[cell.dateKey] ?? [:]
                        let trimmed = updatedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            day.removeValue(forKey: cell.mealSlot)
                        } else {
                            day[cell.mealSlot] = trimmed
                        }
                        store.mealPlans[cell.dateKey] = day
                        store.showToast("已更新 \(cell.dateKey) \(cell.mealSlot.title)")
                    },
                    onDelete: {
                        var day = store.mealPlans[cell.dateKey] ?? [:]
                        day.removeValue(forKey: cell.mealSlot)
                        store.mealPlans[cell.dateKey] = day
                        store.showToast("已清除安排")
                    }
                )
            }
        }
    }

    private func showCurrentWeek() {
        weekStart = DateHelper.weekStart(for: Date())
        focusedDateKey = DateHelper.todayKey
    }

    private func moveWeek(by days: Int) {
        weekStart = Calendar.current.date(byAdding: .day, value: days, to: weekStart) ?? weekStart
        syncFocusedDateIfNeeded()
    }

    private func syncFocusedDateIfNeeded() {
        let availableKeys = Set(weekDates.map(DateHelper.key(for:)))
        if !availableKeys.contains(focusedDateKey) {
            focusedDateKey = DateHelper.key(for: weekDates.first ?? weekStart)
        }
    }
}

// MARK: - AI Chef Panel

struct AIChefPanel: View {
    @Environment(KitchenStore.self) private var store

    @Binding var planDate: String
    let weekDates: [Date]

    @State private var mode: AIChefMode = .suggest
    @State private var dishName = ""
    @State private var recipeResult: AIRecipeResult?
    @State private var suggestions: [AISuggestion] = []
    @State private var selectedSuggestionID: UUID?
    @State private var planMeal = MealSlot.dinner
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var hasLoadedInitialSuggestions = false

    private var selectedSuggestion: AISuggestion? {
        suggestions.first(where: { $0.id == selectedSuggestionID })
    }

    var body: some View {
        ZaoWangyeCardShell(
            eyebrow: mode == .suggest ? "库存驱动推荐" : "手动点菜模式",
            title: "灶王爷",
            subtitle: "点菜、核库存、补待购，把菜单安排和缺货补单一起管起来。",
            imageSize: 120
        ) {
            HStack(alignment: .center, spacing: 12) {
                Text(mode == .suggest ? "优先消耗现有库存，顺手把缺的食材补进待购。" : "输入想吃的菜，灶王爷会帮你核库存并给出补货动作。")
                    .font(.subheadline)
                    .foregroundStyle(KitchenTheme.zaoCream.opacity(0.92))

                Spacer(minLength: 0)

                if mode == .suggest && !isLoading {
                    Button("刷新推荐") { fetchSuggestions() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.18), in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        )
                }
            }

            ZaoWangyeInsetPanel {
                Picker("灶王爷模式", selection: $mode) {
                    ForEach(AIChefMode.allCases) { item in
                        Label(item.title, systemImage: item.symbolName).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if mode == .input {
                    inputModeContent
                } else {
                    suggestModeContent
                }
            }
        }
        .onAppear { loadInitialSuggestionsIfNeeded() }
        .onChange(of: mode) { _, newMode in handleModeChange(newMode) }
    }

    @ViewBuilder
    private var inputModeContent: some View {
        TextField("输入菜名", text: $dishName)
            .textFieldStyle(.roundedBorder)

        FilledButton(title: isLoading ? "查询中…" : "查菜谱并核库存") {
            fetchRecipe()
        }
        .disabled(isLoading || dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if isLoading {
            LoadingRow(text: "正在查食谱并核对库存…")
        }

        if !errorMessage.isEmpty {
            Text(errorMessage).font(.caption).foregroundStyle(.red)
        }

        if let recipeResult {
            RecipeResultCard(
                result: recipeResult,
                planDate: $planDate,
                planMeal: $planMeal,
                weekDates: weekDates,
                onAssign: { assignMeal(recipeResult.dish) },
                onAddToShopping: { addMissingIngredients(recipeResult.ingredients) },
                onAutoPilot: { autoArrangeMeal(recipeResult.dish, ingredients: recipeResult.ingredients) }
            )
        }
    }

    @ViewBuilder
    private var suggestModeContent: some View {
        if isLoading {
            LoadingRow(text: "正在根据库存整理建议…")
        }

        if !errorMessage.isEmpty {
            Text(errorMessage).font(.caption).foregroundStyle(.red)
        }

        if !isLoading && suggestions.isEmpty && errorMessage.isEmpty {
            Text("库存太少，先补几样再来。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        ForEach(Array(suggestions.prefix(3))) { suggestion in
            SuggestionCard(
                suggestion: suggestion,
                isSelected: selectedSuggestionID == suggestion.id
            )
            .onTapGesture {
                selectedSuggestionID = selectedSuggestionID == suggestion.id ? nil : suggestion.id
            }
        }

        if let selectedSuggestion {
            suggestionActionPanel(selectedSuggestion)
        }
    }

    @ViewBuilder
    private func suggestionActionPanel(_ suggestion: AISuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("安排「\(suggestion.dish)」")
                .font(.subheadline.weight(.semibold))

            if suggestion.canCookNow {
                Label("食材齐了。", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(KitchenTheme.zaoMint)
            } else {
                Text("还缺 \(suggestion.missingIngredients.count) 项，可自动补货。")
                    .font(.caption)
                    .foregroundStyle(KitchenTheme.zaoCream.opacity(0.82))
            }

            if !suggestion.missingIngredients.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(suggestion.missingIngredients) { ingredient in
                        Text("\(ingredient.name) \(ingredient.purchaseQuantityText)\(ingredient.unit)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(KitchenTheme.zaoCream)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.10), in: Capsule())
                    }
                }
            }

            PlanSelector(planDate: $planDate, planMeal: $planMeal, weekDates: weekDates)

            if suggestion.canCookNow {
                FilledButton(title: "安排到菜单") { assignMeal(suggestion.dish) }
            } else {
                FilledButton(title: "安排并补齐待购") {
                    autoArrangeMeal(suggestion.dish, ingredients: suggestion.ingredients)
                }
                SecondaryButton(title: "仅加入购物清单", symbol: "cart.badge.plus") {
                    addMissingIngredients(suggestion.missingIngredients)
                }
            }

            SecondaryButton(title: "只安排", symbol: "calendar.badge.plus") {
                assignMeal(suggestion.dish)
            }
        }
        .padding(14)
        .zaoWangyeSurface(selected: true)
    }

    // MARK: - Actions

    private func handleModeChange(_ newMode: AIChefMode) {
        recipeResult = nil
        suggestions = []
        selectedSuggestionID = nil
        errorMessage = ""
        if newMode == .suggest { fetchSuggestions() }
    }

    private func fetchRecipe() {
        let trimmed = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = ""
        recipeResult = nil
        Task {
            do {
                let result = try await AIChefEngine.recipe(for: trimmed, inventory: store.inventoryItems, store: store)
                recipeResult = result
            } catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }

    private func fetchSuggestions() {
        isLoading = true
        errorMessage = ""
        suggestions = []
        selectedSuggestionID = nil
        Task {
            do {
                let result = try await AIChefEngine.suggestions(from: store.inventoryItems, store: store)
                suggestions = result
                selectedSuggestionID = result.first?.id
                if suggestions.isEmpty { errorMessage = "没找到推荐，先补库存。" }
            } catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }

    private func assignMeal(_ dish: String) {
        let title = dish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.assignMeal(title, dateKey: planDate, slot: planMeal)
        store.showToast("已安排「\(title)」到 \(planDate) \(planMeal.title)")
    }

    private func addMissingIngredients(_ ingredients: [RecipeIngredient]) {
        let shoppingDay = store.preferredShoppingDay(for: planDate)
        let summary = store.syncMissingIngredientsToShoppingList(ingredients, preferredDay: shoppingDay)
        guard !summary.isEmpty else {
            store.showToast("食材全部备齐，无需购买")
            return
        }
        let itemsText = summary.affectedNames.joined(separator: "、")
        store.showToast(shoppingDay.isEmpty ? "已加入购物清单：\(itemsText)" : "已加入 \(shoppingDay) 购物清单：\(itemsText)")
    }

    private func autoArrangeMeal(_ dish: String, ingredients: [RecipeIngredient]) {
        let title = dish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.assignMeal(title, dateKey: planDate, slot: planMeal)
        let shoppingDay = store.preferredShoppingDay(for: planDate)
        let summary = store.syncMissingIngredientsToShoppingList(ingredients, preferredDay: shoppingDay)
        if summary.isEmpty {
            store.showToast("已安排「\(title)」，库存已足够")
        } else {
            store.showToast("已安排「\(title)」，并补齐待购：\(summary.affectedNames.joined(separator: "、"))")
        }
    }

    private func loadInitialSuggestionsIfNeeded() {
        guard !hasLoadedInitialSuggestions else { return }
        hasLoadedInitialSuggestions = true
        fetchSuggestions()
    }
}

// MARK: - Recipe Result Card

struct RecipeResultCard: View {
    let result: AIRecipeResult
    @Binding var planDate: String
    @Binding var planMeal: MealSlot
    let weekDates: [Date]
    let onAssign: () -> Void
    let onAddToShopping: () -> Void
    let onAutoPilot: () -> Void

    private var missingCount: Int { result.missingIngredients.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.dish).font(.headline)
                    Text(result.tips)
                        .font(.caption)
                        .foregroundStyle(KitchenTheme.zaoCream.opacity(0.82))
                }
                Spacer()
                Text(missingCount == 0 ? "可直接做" : "缺 \(missingCount) 样")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(missingCount == 0 ? KitchenTheme.zaoMint : KitchenTheme.zaoGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((missingCount == 0 ? KitchenTheme.zaoMint : KitchenTheme.zaoGold).opacity(0.16), in: Capsule())
            }

            ForEach(result.ingredients) { ingredient in
                RecipeIngredientRow(ingredient: ingredient)
            }

            PlanSelector(planDate: $planDate, planMeal: $planMeal, weekDates: weekDates)

            if result.canCookNow {
                FilledButton(title: "安排到菜单") { onAssign() }
            } else {
                FilledButton(title: "安排并补齐待购") { onAutoPilot() }
                SecondaryButton(title: "仅加入购物清单", symbol: "cart.badge.plus") { onAddToShopping() }
                SecondaryButton(title: "只安排", symbol: "calendar.badge.plus") { onAssign() }
            }
        }
        .padding(14)
        .zaoWangyeSurface(selected: true)
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    let suggestion: AISuggestion
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.dish)
                        .font(.subheadline.weight(.semibold))
                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundStyle(KitchenTheme.zaoCream.opacity(0.82))
                        .lineLimit(isSelected ? 3 : 2)
                }
                Spacer()
                Text(suggestion.canCookNow ? "可直接做" : "缺 \(suggestion.missingIngredients.count) 样")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(suggestion.canCookNow ? KitchenTheme.zaoMint : KitchenTheme.zaoGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((suggestion.canCookNow ? KitchenTheme.zaoMint : KitchenTheme.zaoGold).opacity(0.16), in: Capsule())
            }

            if isSelected && !suggestion.missingIngredients.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(suggestion.missingIngredients) { ingredient in
                        Text("\(ingredient.name) \(ingredient.purchaseQuantityText)\(ingredient.unit)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(KitchenTheme.zaoCream)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.10), in: Capsule())
                    }
                }
            }
        }
        .padding(12)
        .zaoWangyeSurface(selected: isSelected)
    }
}

// MARK: - Week Day Button

private struct CompactWeekDayButton: View {
    let weekday: String
    let dayText: String
    let mealCount: Int
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(weekday)
                    .font(.caption2.weight(.semibold))
                Text(dayText)
                    .font(.subheadline.weight(.bold))
                if mealCount > 0 {
                    Text("\(mealCount)项")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                (isSelected || isToday ? KitchenTheme.accentTint : Color(.tertiarySystemFill)),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meal Slot Row

private struct CompactMealSlotRow: View {
    let slot: MealSlot
    let value: String?
    let isToday: Bool
    let action: () -> Void
    var onComplete: (() -> Void)? = nil

    private var isDone: Bool {
        value?.hasPrefix("✅") == true
    }

    private var displayValue: String {
        guard let v = value, !v.isEmpty else { return "未安排" }
        return isDone ? String(v.dropFirst(2)) : v
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : slot.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isDone ? .green : Color.accentColor)
                .frame(width: 26, height: 26)
                .background(isDone ? KitchenTheme.greenTint : KitchenTheme.accentTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(slot.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(displayValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle((value?.isEmpty == false ? (isDone ? Color.green : Color.primary) : Color(.tertiaryLabel)))
                    .lineLimit(1)
            }

            Spacer()

            if isToday && value?.isEmpty == false && !isDone {
                Button {
                    onComplete?()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                        .padding(6)
                        .background(KitchenTheme.greenTint, in: Circle())
                }
                .buttonStyle(.plain)
            }

            Button(action: action) {
                Image(systemName: value?.isEmpty == false ? "pencil" : "plus")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            Color(.tertiarySystemFill),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

// MARK: - Recipe Ingredient Row

private struct RecipeIngredientRow: View {
    let ingredient: RecipeIngredient

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: ingredient.needToBuy ? "minus.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(ingredient.needToBuy ? .red : .green)

            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name).font(.subheadline.weight(.medium))
                Text(
                    ingredient.needToBuy
                    ? "需 \(ingredient.quantity.cleanString)\(ingredient.unit) · 现有 \(ingredient.currentQuantity) · 待购 \(ingredient.purchaseQuantityText)\(ingredient.unit)"
                    : "需 \(ingredient.quantity.cleanString)\(ingredient.unit) · 现有 \(ingredient.currentQuantity)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(ingredient.needToBuy ? "缺货" : "已备")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ingredient.needToBuy ? .red : .green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ingredient.needToBuy ? KitchenTheme.redTint : KitchenTheme.greenTint, in: Capsule())
        }
        .padding(10)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Meal Edit Sheet

struct MealEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let state: MealCellEditingState
    let onSave: (String) -> Void
    let onDelete: () -> Void

    @State private var value: String

    init(state: MealCellEditingState, onSave: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.state = state
        self.onSave = onSave
        self.onDelete = onDelete
        _value = State(initialValue: state.value)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(state.mealSlot.title, systemImage: state.mealSlot.symbolName)
                        .font(.headline)
                    Text(state.dateKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    TextField("输入食物，多个用逗号分隔", text: $value)
                }

                Section {
                    Button("保存") {
                        onSave(value)
                        dismiss()
                    }
                    .fontWeight(.semibold)

                    if !state.value.isEmpty {
                        Button("清除", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("编辑餐次")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
