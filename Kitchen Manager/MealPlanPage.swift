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
                                        .foregroundStyle(Color.accentColor)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(KitchenTheme.accentTint, in: Capsule())
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
                                        .foregroundStyle(Color.accentColor)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(KitchenTheme.accentTint, in: Capsule())
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
                                            store.showToast("\(slot.title) 已完成")
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
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Text(dayNumber)
                    .font(.system(size: 18, weight: isSelected || isToday ? .bold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)

                Circle()
                    .fill(
                        mealCount > 0
                        ? (isSelected ? Color.accentColor : Color.secondary.opacity(0.38))
                        : Color.clear
                    )
                    .frame(width: 5, height: 5)
            }
            .frame(width: 44, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected ? Color.accentColor.opacity(0.12)
                        : (isToday ? Color.accentColor.opacity(0.06) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.28) : Color.clear, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
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
            // ── Compact header band ───────────────────────────────────
            ZStack(alignment: .leading) {
                // Background gradient
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.25, green: 0.06, blue: 0.03), location: 0.0),
                        .init(color: Color(red: 0.52, green: 0.13, blue: 0.05), location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle glow behind avatar
                Circle()
                    .fill(KitchenTheme.zaoSun.opacity(0.30))
                    .frame(width: 80)
                    .blur(radius: 28)
                    .offset(x: 12, y: 4)

                HStack(spacing: 12) {
                    // Avatar
                    Image("ZaoWangyeHero")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .overlay(
                            Circle().strokeBorder(
                                LinearGradient(
                                    colors: [KitchenTheme.zaoGold.opacity(0.85), .white.opacity(0.20)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                        )
                        .shadow(color: KitchenTheme.zaoGold.opacity(0.35), radius: 10, y: 3)

                    // Title
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mode == .suggest ? "库存优先" : "手动点菜")
                            .font(.caption2.weight(.semibold))
                            .kerning(0.5)
                            .foregroundStyle(KitchenTheme.zaoGold.opacity(0.85))
                        Text("灶王爷")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }

                    Spacer(minLength: 8)

                    // Mode toggle inline in header
                    AIChefModeSwitch(selection: $mode)
                        .frame(maxWidth: 148)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .frame(height: 80)

            // Gold divider line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [KitchenTheme.zaoGold.opacity(0.55), KitchenTheme.zaoGold.opacity(0.05)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 1)

            // ── Content area ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 12) {
                if mode == .input {
                    inputModeContent
                } else {
                    suggestModeContent
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.12, green: 0.05, blue: 0.03))
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: KitchenTheme.zaoGold.opacity(0.70), location: 0.0),
                            .init(color: .white.opacity(0.08), location: 0.50),
                            .init(color: KitchenTheme.zaoGold.opacity(0.20), location: 1.0),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        )
        .shadow(color: Color(red: 0.40, green: 0.08, blue: 0.02).opacity(0.55), radius: 20, y: 10)
        .onAppear { loadInitialSuggestionsIfNeeded() }
        .onChange(of: mode) { _, newMode in handleModeChange(newMode) }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if isLoading {
            LoadingRow(text: "处理中…")
        }
        if !errorMessage.isEmpty {
            Text(errorMessage).font(.caption).foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var inputModeContent: some View {
        TextField("输入菜名", text: $dishName)
            .textFieldStyle(.roundedBorder)
            .colorScheme(.dark)

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
                        .foregroundStyle(.white.opacity(0.72))
                }
                .buttonStyle(.plain)
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
        store.showToast("已安排「\(title)」")
    }

    private func addMissingIngredients(_ ingredients: [RecipeIngredient]) {
        let shoppingDay = store.preferredShoppingDay(for: planDate)
        let summary = store.syncMissingIngredientsToShoppingList(ingredients, preferredDay: shoppingDay)
        guard !summary.isEmpty else {
            store.showToast("食材全部备齐，无需购买")
            return
        }
        let itemsText = summary.affectedNames.joined(separator: "、")
        store.showToast("已加入待购：\(itemsText)")
    }

    private func autoArrangeMeal(_ dish: String, ingredients: [RecipeIngredient]) {
        let title = dish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.assignMeal(title, dateKey: planDate, slot: planMeal)
        let shoppingDay = store.preferredShoppingDay(for: planDate)
        let summary = store.syncMissingIngredientsToShoppingList(ingredients, preferredDay: shoppingDay)
        if summary.isEmpty {
            store.showToast("已安排「\(title)」")
        } else {
            store.showToast("已安排并补货 \(summary.affectedNames.count) 项")
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
                    Text(result.dish)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(result.tips)
                        .font(.caption)
                        .foregroundStyle(KitchenTheme.zaoCream.opacity(0.78))
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

private struct AIChefModeSwitch: View {
    @Binding var selection: AIChefMode

    var body: some View {
        HStack(spacing: 4) {
            modeButton(.suggest, label: "推荐")
            modeButton(.input, label: "点菜")
        }
        .padding(4)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            .foregroundStyle(isSelected ? KitchenTheme.zaoCrimson : .white.opacity(0.72))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? KitchenTheme.zaoGold : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
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
                    .foregroundStyle(KitchenTheme.zaoGold)
                Text("\(suggestions.count) 道推荐")
                    .foregroundStyle(KitchenTheme.zaoGold)
                Text("·")
                    .foregroundStyle(.white.opacity(0.35))
                Text("\(readyCount) 可直接做")
                    .foregroundStyle(KitchenTheme.zaoMint)
                if missingCount > 0 {
                    Text("·")
                        .foregroundStyle(.white.opacity(0.35))
                    Text("\(missingCount) 需补货")
                        .foregroundStyle(KitchenTheme.zaoAmber)
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
            // ── Always-visible summary row ──────────────────────────────
            HStack(spacing: 10) {
                // Rank badge
                Text("\(rank)")
                    .font(.caption.weight(.black).monospacedDigit())
                    .foregroundStyle(isSelected ? KitchenTheme.zaoCrimson : .white)
                    .frame(width: 26, height: 26)
                    .background(
                        isSelected ? KitchenTheme.zaoGold : .white.opacity(0.16),
                        in: Circle()
                    )

                // Dish info
                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.dish)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundStyle(KitchenTheme.zaoCream.opacity(0.78))
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                // Status badge
                Text(suggestion.canCookNow ? "现成" : "缺\(suggestion.missingIngredients.count)样")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(suggestion.canCookNow ? KitchenTheme.zaoMint : KitchenTheme.zaoGold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        (suggestion.canCookNow ? KitchenTheme.zaoMint : KitchenTheme.zaoGold).opacity(0.16),
                        in: Capsule()
                    )

                // Chevron
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.40))
                    .rotationEffect(.degrees(isSelected ? -180 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)

            // ── Expanded detail + actions ──────────────────────────────
            if isSelected {
                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(height: 1)
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 11) {
                    // Readiness label
                    if suggestion.canCookNow {
                        Label("食材全部备齐，可直接下锅。", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(KitchenTheme.zaoMint)
                    } else {
                        Label("还缺 \(suggestion.missingIngredients.count) 样食材。", systemImage: "exclamationmark.circle")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(KitchenTheme.zaoCream.opacity(0.82))
                    }

                    // Missing ingredient chips
                    if !suggestion.missingIngredients.isEmpty {
                        FlowLayout(spacing: 5) {
                            ForEach(suggestion.missingIngredients) { ingredient in
                                HStack(spacing: 3) {
                                    Image(systemName: "plus.circle")
                                        .font(.caption2.weight(.semibold))
                                    Text("\(ingredient.name) \(ingredient.purchaseQuantityText)\(ingredient.unit)")
                                        .font(.caption2.weight(.semibold))
                                }
                                .foregroundStyle(KitchenTheme.zaoCream.opacity(0.88))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.12), in: Capsule())
                                .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.8))
                            }
                        }
                    }

                    // Plan selector
                    PlanSelector(planDate: $planDate, planMeal: $planMeal, weekDates: weekDates)

                    // Action buttons
                    if suggestion.canCookNow {
                        FilledButton(title: "安排到菜单") { onAssign() }
                    } else {
                        FilledButton(title: "安排并补齐待购") { onAutoArrange() }
                        SecondaryButton(title: "仅加入购物清单", symbol: "cart.badge.plus") { onAddToShopping() }
                        SecondaryButton(title: "只安排", symbol: "calendar.badge.plus") { onAssign() }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 11)
                .padding(.bottom, 13)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? .white.opacity(0.15) : .black.opacity(0.20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isSelected ? KitchenTheme.zaoGold.opacity(0.82) : .white.opacity(0.09),
                    lineWidth: isSelected ? 1.5 : 1
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
            HStack(spacing: 12) {
                // Icon — larger, fills with green when done
                Image(systemName: isDone ? "checkmark.circle.fill" : slot.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDone ? .white : Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(
                        isDone ? Color.green : KitchenTheme.accentTint,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                // Labels
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    if hasValue {
                        Text(displayValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isDone ? Color.secondary : Color.primary)
                            .strikethrough(isDone, color: Color.secondary)
                            .lineLimit(1)
                    } else {
                        Text("点击添加")
                            .font(.subheadline)
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }

                Spacer()

                // Right-side actions
                HStack(spacing: 10) {
                    if isToday && hasValue && !isDone {
                        Button {
                            onComplete?()
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .font(.title3)
                                .foregroundStyle(Color.green)
                        }
                        .buttonStyle(.plain)
                    }

                    Image(systemName: hasValue ? "chevron.right" : "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isDone ? KitchenTheme.greenTint : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recipe Ingredient Row

private struct RecipeIngredientRow: View {
    let ingredient: RecipeIngredient

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: ingredient.needToBuy ? "cart.badge.plus" : "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ingredient.needToBuy ? KitchenTheme.zaoGold : KitchenTheme.zaoMint)
                .frame(width: 20, height: 20)

            Text(ingredient.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(ingredient.needToBuy ? "待购 \(ingredient.purchaseQuantityText)\(ingredient.unit)" : "已备")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ingredient.needToBuy ? KitchenTheme.zaoGold : KitchenTheme.zaoMint)
                Text("需 \(ingredient.quantity.cleanString)\(ingredient.unit)")
                    .font(.caption2)
                    .foregroundStyle(KitchenTheme.zaoCream.opacity(0.55))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
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
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 42, height: 42)
                    .background(KitchenTheme.accentTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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
