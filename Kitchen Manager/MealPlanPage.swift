import SwiftUI

struct MealPlanPage: View {
    @Environment(KitchenStore.self) private var store

    @State private var weekStart = DateHelper.weekStart(for: Date())
    @State private var focusedDateKey = DateHelper.todayKey
    @State private var editingCell: MealCellEditingState?

    private var weekDates: [Date] { DateHelper.weekDates(from: weekStart) }

    private var weekLabel: String {
        guard let last = weekDates.last else { return "" }
        return "\(DateHelper.monthDayString(weekStart)) – \(DateHelper.monthDayString(last))"
    }

    private var plannedCount: Int {
        weekDates.reduce(0) { total, date in
            let meals = store.mealPlans[DateHelper.key(for: date)] ?? [:]
            return total + meals.values.filter { !$0.isEmpty }.count
        }
    }

    private var focusedDate: Date { DateHelper.date(from: focusedDateKey) ?? weekStart }

    private var focusedMeals: [MealSlot: String] { store.mealPlans[focusedDateKey] ?? [:] }

    private var focusedMealCount: Int { focusedMeals.values.filter { !$0.isEmpty }.count }

    private var isCurrentWeek: Bool {
        Calendar.current.isDate(weekStart, inSameDayAs: DateHelper.weekStart(for: Date()))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AIChefPanel(planDate: $focusedDateKey, weekDates: weekDates)

                    // ── Week Planner Card ───────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {

                        // Header
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("本周安排")
                                    .font(.headline)
                                Text(weekLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                if !isCurrentWeek {
                                    Button("今天") { showCurrentWeek() }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(KitchenTheme.brandCrimson)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(KitchenTheme.brandCrimson.opacity(0.08), in: Capsule())
                                }

                                Button { moveWeek(by: -7) } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 30, height: 30)
                                .background(Color(.tertiarySystemFill), in: Circle())

                                Button { moveWeek(by: 7) } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 30, height: 30)
                                .background(Color(.tertiarySystemFill), in: Circle())
                            }
                        }
                        .padding(16)

                        // Day strip — horizontal scroll, single row
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(weekDates, id: \.self) { date in
                                    let dateKey = DateHelper.key(for: date)
                                    WeekDayPill(
                                        date: date,
                                        mealCount: (store.mealPlans[dateKey] ?? [:])
                                            .values.filter { !$0.isEmpty }.count,
                                        isSelected: focusedDateKey == dateKey,
                                        isToday: dateKey == DateHelper.todayKey
                                    ) {
                                        withAnimation(.spring(duration: 0.22)) {
                                            focusedDateKey = dateKey
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                        .padding(.bottom, 4)

                        Divider()

                        // Focused day detail
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(DateHelper.weekdayName(for: focusedDate))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                    Text(DateHelper.monthDayString(focusedDate))
                                        .font(.title3.weight(.bold))
                                }

                                Spacer()

                                if focusedMealCount > 0 {
                                    Text("\(focusedMealCount)/\(MealSlot.allCases.count) 项已安排")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(KitchenTheme.brandCrimson)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(KitchenTheme.brandCrimson.opacity(0.08), in: Capsule())
                                }
                            }

                            VStack(spacing: 8) {
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
                                            store.showToast("好,这顿\(slot.title)吃完了。", kind: .success)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(16)
                    }
                    .background(KitchenTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(KitchenTheme.background)
            .navigationTitle("菜单")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    KitchenBrandMark()
                }
            }
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

// MARK: - Week Day Pill

private struct WeekDayPill: View {
    let date: Date
    let mealCount: Int
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }

    private var weekdayLetter: String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f.string(from: date)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(weekdayLetter)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : KitchenTheme.textSecondary)

                Text(dayNumber)
                    .font(.system(size: 18, weight: isSelected || isToday ? .bold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white : KitchenTheme.textPrimary)

                Circle()
                    .fill(dotColor)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 44, height: 64)
            .background(
                RoundedRectangle(cornerRadius: KitchenTheme.Radius.md, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: KitchenTheme.Radius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(KitchenPressStyle())
    }

    private var dotColor: Color {
        guard mealCount > 0 else { return .clear }
        if isSelected { return KitchenTheme.brandGold }
        if isToday    { return KitchenTheme.brandGold.opacity(0.85) }
        return KitchenTheme.textSecondary.opacity(0.45)
    }

    private var backgroundColor: Color {
        if isSelected { return KitchenTheme.brandCrimson }
        if isToday    { return KitchenTheme.brandGold.opacity(0.10) }
        return .clear
    }

    private var borderColor: Color {
        if isSelected { return KitchenTheme.brandGold.opacity(0.40) }
        if isToday    { return KitchenTheme.brandGold.opacity(0.45) }
        return .clear
    }

    private var borderWidth: CGFloat {
        (isSelected || isToday) ? 1 : 0
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
        VStack(alignment: .leading, spacing: 0) {
            // Header strip — cream paper with brand mark + mode toggle
            HStack(spacing: KitchenTheme.Spacing.md) {
                Image("ZaoWangyeHero")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(KitchenTheme.brandGold.opacity(0.85), lineWidth: 1.5)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode == .suggest ? "库存优先" : "手动点菜")
                        .font(KitchenType.eyebrow)
                        .kerning(0.5)
                        .foregroundStyle(KitchenTheme.brandCrimson)
                    Text("灶王爷")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(KitchenTheme.textPrimary)
                }

                Spacer(minLength: KitchenTheme.Spacing.sm)

                AIChefModeSwitch(selection: $mode)
                    .frame(maxWidth: 148)
            }
            .padding(.horizontal, KitchenTheme.Spacing.lg)
            .padding(.vertical, KitchenTheme.Spacing.md + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KitchenTheme.brandCream)

            // Subtle divider
            Rectangle()
                .fill(KitchenTheme.brandGold.opacity(0.30))
                .frame(height: 0.5)

            // Content area on neutral surface
            VStack(alignment: .leading, spacing: KitchenTheme.Spacing.md) {
                if mode == .input {
                    inputModeContent
                } else {
                    suggestModeContent
                }
            }
            .padding(KitchenTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KitchenTheme.surfaceElevated)
        }
        .clipShape(RoundedRectangle(cornerRadius: KitchenTheme.Radius.lg + 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTheme.Radius.lg + 2, style: .continuous)
                .strokeBorder(KitchenTheme.brandGold.opacity(0.30), lineWidth: 1)
        )
        .kitchenShadow()
        .onAppear { loadInitialSuggestionsIfNeeded() }
        .onChange(of: mode) { _, newMode in handleModeChange(newMode) }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if isLoading {
            LoadingRow(text: "处理中…")
        }
        if !errorMessage.isEmpty {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(KitchenTheme.danger)
        }
    }

    @ViewBuilder
    private var inputModeContent: some View {
        TextField("输入菜名", text: $dishName)
            .textFieldStyle(.roundedBorder)

        FilledButton(title: isLoading ? "查询中…" : "查菜谱") {
            fetchRecipe()
        }
        .disabled(isLoading || dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        statusOverlay

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
        HStack(alignment: .center) {
            SuggestionOverviewPanel(
                suggestions: Array(suggestions.prefix(3)),
                isLoading: isLoading
            )
            if !isLoading {
                Button {
                    fetchSuggestions()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KitchenTheme.textSecondary)
                }
                .buttonStyle(KitchenPressStyle())
            }
        }

        statusOverlay

        if !isLoading && suggestions.isEmpty && errorMessage.isEmpty {
            Text("库存太少，先补几样再来。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        ForEach(Array(suggestions.prefix(3).enumerated()), id: \.element.id) { index, suggestion in
            SuggestionCard(
                suggestion: suggestion,
                rank: index + 1,
                isSelected: selectedSuggestionID == suggestion.id,
                planDate: $planDate,
                planMeal: $planMeal,
                weekDates: weekDates,
                onAssign: { assignMeal(suggestion.dish) },
                onAutoArrange: { autoArrangeMeal(suggestion.dish, ingredients: suggestion.ingredients) },
                onAddToShopping: { addMissingIngredients(suggestion.missingIngredients) }
            )
            .onTapGesture {
                withAnimation(.spring(duration: 0.28, bounce: 0.08)) {
                    selectedSuggestionID = selectedSuggestionID == suggestion.id ? nil : suggestion.id
                }
            }
        }
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
        store.showToast("「\(title)」我记上了。", kind: .success)
    }

    private func addMissingIngredients(_ ingredients: [RecipeIngredient]) {
        let shoppingDay = store.preferredShoppingDay(for: planDate)
        let summary = store.syncMissingIngredientsToShoppingList(ingredients, preferredDay: shoppingDay)
        guard !summary.isEmpty else {
            store.showToast("食材都齐了,不用买。", kind: .success)
            return
        }
        let itemsText = summary.affectedNames.joined(separator: "、")
        store.showToast("加进清单了：\(itemsText)。", kind: .success)
    }

    private func autoArrangeMeal(_ dish: String, ingredients: [RecipeIngredient]) {
        let title = dish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.assignMeal(title, dateKey: planDate, slot: planMeal)
        let shoppingDay = store.preferredShoppingDay(for: planDate)
        let summary = store.syncMissingIngredientsToShoppingList(ingredients, preferredDay: shoppingDay)
        if summary.isEmpty {
            store.showToast("「\(title)」我记上了。", kind: .success)
        } else {
            store.showToast("「\(title)」我记上了,顺手补了 \(summary.affectedNames.count) 项。", kind: .success)
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
        VStack(alignment: .leading, spacing: KitchenTheme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.dish)
                        .font(.headline)
                        .foregroundStyle(KitchenTheme.textPrimary)
                    Text(result.tips)
                        .font(.caption)
                        .foregroundStyle(KitchenTheme.textSecondary)
                }
                Spacer()
                Text(missingCount == 0 ? "可直接做" : "缺 \(missingCount) 样")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(missingCount == 0 ? KitchenTheme.success : KitchenTheme.brandCrimson)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (missingCount == 0 ? KitchenTheme.success : KitchenTheme.brandCrimson).opacity(0.12),
                        in: Capsule()
                    )
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
        .padding(KitchenTheme.Spacing.md + 2)
        .background(
            KitchenTheme.brandCream.opacity(0.45),
            in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.md + 2, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTheme.Radius.md + 2, style: .continuous)
                .strokeBorder(KitchenTheme.brandGold.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct AIChefModeSwitch: View {
    @Binding var selection: AIChefMode

    var body: some View {
        HStack(spacing: 4) {
            modeButton(.suggest, label: "推荐")
            modeButton(.input, label: "点菜")
        }
        .padding(4)
        .background(
            KitchenTheme.surfaceElevated,
            in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.md, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTheme.Radius.md, style: .continuous)
                .strokeBorder(KitchenTheme.separator.opacity(0.5), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func modeButton(_ mode: AIChefMode, label: String) -> some View {
        let isSelected = selection == mode
        Button {
            selection = mode
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.symbolName)
                    .font(.caption.weight(.semibold))
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Color.white : KitchenTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? KitchenTheme.brandCrimson : .clear,
                in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.sm, style: .continuous)
            )
        }
        .buttonStyle(KitchenPressStyle())
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

private struct SuggestionOverviewPanel: View {
    let suggestions: [AISuggestion]
    let isLoading: Bool

    private var readyCount: Int { suggestions.filter(\.canCookNow).count }
    private var missingCount: Int { suggestions.count - readyCount }

    var body: some View {
        if !isLoading && !suggestions.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KitchenTheme.brandCrimson)
                Text("\(suggestions.count) 道推荐")
                    .foregroundStyle(KitchenTheme.textPrimary)
                Text("·")
                    .foregroundStyle(KitchenTheme.textTertiary)
                Text("\(readyCount) 可直接做")
                    .foregroundStyle(KitchenTheme.success)
                if missingCount > 0 {
                    Text("·")
                        .foregroundStyle(KitchenTheme.textTertiary)
                    Text("\(missingCount) 需补货")
                        .foregroundStyle(KitchenTheme.warning)
                }
                Spacer(minLength: 0)
            }
            .font(.caption.weight(.medium))
        }
    }
}

// MARK: - Suggestion Card (self-contained with integrated action panel)

struct SuggestionCard: View {
    let suggestion: AISuggestion
    let rank: Int
    let isSelected: Bool
    @Binding var planDate: String
    @Binding var planMeal: MealSlot
    let weekDates: [Date]
    let onAssign: () -> Void
    let onAutoArrange: () -> Void
    let onAddToShopping: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Summary row
            HStack(spacing: KitchenTheme.Spacing.sm + 2) {
                Text("\(rank)")
                    .font(.caption.weight(.black).monospacedDigit())
                    .foregroundStyle(isSelected ? Color.white : KitchenTheme.brandCrimson)
                    .frame(width: 26, height: 26)
                    .background(
                        isSelected ? KitchenTheme.brandCrimson : KitchenTheme.brandCrimson.opacity(0.10),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.dish)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KitchenTheme.textPrimary)
                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundStyle(KitchenTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text(suggestion.canCookNow ? "现成" : "缺\(suggestion.missingIngredients.count)样")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(suggestion.canCookNow ? KitchenTheme.success : KitchenTheme.warning)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        (suggestion.canCookNow ? KitchenTheme.success : KitchenTheme.warning).opacity(0.12),
                        in: Capsule()
                    )

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(KitchenTheme.textTertiary)
                    .rotationEffect(.degrees(isSelected ? -180 : 0))
            }
            .padding(.horizontal, KitchenTheme.Spacing.md)
            .padding(.vertical, 11)

            // Expanded detail
            if isSelected {
                Rectangle()
                    .fill(KitchenTheme.separator.opacity(0.6))
                    .frame(height: 0.5)
                    .padding(.horizontal, KitchenTheme.Spacing.md)

                VStack(alignment: .leading, spacing: 11) {
                    if suggestion.canCookNow {
                        Label("食材全部备齐，可直接下锅。", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(KitchenTheme.success)
                    } else {
                        Label("还缺 \(suggestion.missingIngredients.count) 样食材。", systemImage: "exclamationmark.circle")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(KitchenTheme.textSecondary)
                    }

                    if !suggestion.missingIngredients.isEmpty {
                        FlowLayout(spacing: 5) {
                            ForEach(suggestion.missingIngredients) { ingredient in
                                HStack(spacing: 3) {
                                    Image(systemName: "plus.circle")
                                        .font(.caption2.weight(.semibold))
                                    Text("\(ingredient.name) \(ingredient.purchaseQuantityText)\(ingredient.unit)")
                                        .font(.caption2.weight(.semibold))
                                }
                                .foregroundStyle(KitchenTheme.brandCrimson)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(KitchenTheme.brandCrimson.opacity(0.08), in: Capsule())
                            }
                        }
                    }

                    PlanSelector(planDate: $planDate, planMeal: $planMeal, weekDates: weekDates)

                    if suggestion.canCookNow {
                        FilledButton(title: "安排到菜单") { onAssign() }
                    } else {
                        FilledButton(title: "安排并补齐待购") { onAutoArrange() }
                        SecondaryButton(title: "仅加入购物清单", symbol: "cart.badge.plus") { onAddToShopping() }
                        SecondaryButton(title: "只安排", symbol: "calendar.badge.plus") { onAssign() }
                    }
                }
                .padding(.horizontal, KitchenTheme.Spacing.md)
                .padding(.top, 11)
                .padding(.bottom, 13)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: KitchenTheme.Radius.md + 2, style: .continuous)
                .fill(isSelected ? KitchenTheme.brandCream.opacity(0.45) : KitchenTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTheme.Radius.md + 2, style: .continuous)
                .strokeBorder(
                    isSelected ? KitchenTheme.brandGold.opacity(0.50) : KitchenTheme.separator.opacity(0.5),
                    lineWidth: isSelected ? 1.2 : 0.5
                )
        )
    }
}

// MARK: - Meal Slot Row

private struct CompactMealSlotRow: View {
    let slot: MealSlot
    let value: String?
    let isToday: Bool
    let action: () -> Void
    var onComplete: (() -> Void)? = nil

    private var isDone: Bool { value?.hasPrefix("✅") == true }
    private var hasValue: Bool { !(value?.isEmpty ?? true) }
    private var displayValue: String {
        guard let v = value, !v.isEmpty else { return "" }
        return isDone ? String(v.dropFirst(2)) : v
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: KitchenTheme.Spacing.md) {
                Image(systemName: isDone ? "checkmark.circle.fill" : slot.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDone ? Color.white : KitchenTheme.brandCrimson)
                    .frame(width: 36, height: 36)
                    .background(
                        isDone ? KitchenTheme.brandGold : KitchenTheme.brandCrimson.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.sm, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(KitchenTheme.textSecondary)
                    if hasValue {
                        Text(displayValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isDone ? KitchenTheme.textSecondary : KitchenTheme.textPrimary)
                            .strikethrough(isDone, color: KitchenTheme.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("点击添加")
                            .font(.subheadline)
                            .foregroundStyle(KitchenTheme.textTertiary)
                    }
                }

                Spacer()

                HStack(spacing: KitchenTheme.Spacing.sm + 2) {
                    if isToday && hasValue && !isDone {
                        Button {
                            onComplete?()
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .font(.title3)
                                .foregroundStyle(KitchenTheme.brandGold)
                        }
                        .buttonStyle(KitchenPressStyle())
                    }

                    Image(systemName: hasValue ? "chevron.right" : "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KitchenTheme.textTertiary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, KitchenTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: KitchenTheme.Radius.md, style: .continuous)
                    .fill(isDone ? KitchenTheme.brandGold.opacity(0.10) : KitchenTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: KitchenTheme.Radius.md, style: .continuous)
                    .strokeBorder(
                        isDone ? KitchenTheme.brandGold.opacity(0.30) : Color.clear,
                        lineWidth: isDone ? 1 : 0
                    )
            )
        }
        .buttonStyle(KitchenPressStyle())
    }
}

// MARK: - Recipe Ingredient Row

private struct RecipeIngredientRow: View {
    let ingredient: RecipeIngredient

    var body: some View {
        HStack(spacing: KitchenTheme.Spacing.sm + 2) {
            Image(systemName: ingredient.needToBuy ? "cart.badge.plus" : "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ingredient.needToBuy ? KitchenTheme.brandCrimson : KitchenTheme.success)
                .frame(width: 20, height: 20)

            Text(ingredient.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(KitchenTheme.textPrimary)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(ingredient.needToBuy ? "待购 \(ingredient.purchaseQuantityText)\(ingredient.unit)" : "已备")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ingredient.needToBuy ? KitchenTheme.brandCrimson : KitchenTheme.success)
                Text("需 \(ingredient.quantity.cleanString)\(ingredient.unit)")
                    .font(.caption2)
                    .foregroundStyle(KitchenTheme.textTertiary)
            }
        }
        .padding(.horizontal, KitchenTheme.Spacing.sm + 2)
        .padding(.vertical, KitchenTheme.Spacing.sm)
        .background(
            KitchenTheme.surface,
            in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.sm, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTheme.Radius.sm, style: .continuous)
                .strokeBorder(KitchenTheme.separator.opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - Meal Edit Sheet

struct MealEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let state: MealCellEditingState
    let onSave: (String) -> Void
    let onDelete: () -> Void

    @State private var value: String
    @FocusState private var isFieldFocused: Bool

    init(state: MealCellEditingState, onSave: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.state = state
        self.onSave = onSave
        self.onDelete = onDelete
        _value = State(initialValue: state.value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.quaternarySystemFill))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Slot header
            HStack(spacing: 14) {
                Image(systemName: state.mealSlot.symbolName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(KitchenTheme.brandCrimson)
                    .frame(width: 42, height: 42)
                    .background(KitchenTheme.brandCrimson.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.mealSlot.title)
                        .font(.headline)
                    Text(state.dateKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            // Input field
            TextField("输入菜名，多个用逗号分隔", text: $value, axis: .vertical)
                .font(.body)
                .lineLimit(2...)
                .padding(14)
                .background(KitchenTheme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .focused($isFieldFocused)

            Spacer()

            // Actions
            VStack(spacing: 10) {
                FilledButton(title: "保存") {
                    onSave(value)
                    dismiss()
                }

                if !state.value.isEmpty {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Text("清除安排")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium])
        .onAppear { isFieldFocused = true }
    }
}
