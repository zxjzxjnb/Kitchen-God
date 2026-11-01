import SwiftUI

struct MealPlanPage: View {
    @Environment(KitchenStore.self) private var store

    @State private var weekStart = DateHelper.weekStart(for: Date())
    @State private var focusedDateKey = DateHelper.todayKey
    @State private var editingCell: MealCellEditingState?
    @State private var showingAssistant = false

    private var weekDates: [Date] { DateHelper.weekDates(from: weekStart) }

    private var weekLabel: String {
        guard let last = weekDates.last else { return "" }
        return "\(DateHelper.monthDayString(weekStart)) – \(DateHelper.monthDayString(last))"
    }

    private var focusedDate: Date { DateHelper.date(from: focusedDateKey) ?? weekStart }

    private var focusedMeals: [MealSlot: String] { store.mealPlans[focusedDateKey] ?? [:] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // ── Week Planner Card ───────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {

                        // Header
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(weekLabel)
                                    .font(.headline)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                if focusedDateKey != DateHelper.todayKey {
                                    Button("今天") { showCurrentWeek() }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(KitchenTheme.brandForeground)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(KitchenTheme.brandCrimson.opacity(0.08), in: Capsule())
                                        .frame(minHeight: 44)
                                }

                                Button { moveWeek(by: -7) } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("上一周")

                                Button { moveWeek(by: 7) } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("下一周")
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
                                            let deducted = store.completeMeal(dateKey: focusedDateKey, slot: slot)
                                            store.showToast(
                                                deducted ? "好,这顿\(slot.title)吃完了,库存也更新了。" : "这顿\(slot.title)记下了；没有可扣减的库存。",
                                                kind: deducted ? .success : .warning
                                            )
                                        }
                                    )
                                }
                            }
                        }
                        .padding(16)
                    }
                    .background(KitchenTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    AssistantEntryButton { showingAssistant = true }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(KitchenTheme.background)
            .navigationTitle("菜单")
            .onAppear { syncFocusedDateIfNeeded() }
            .sheet(item: $editingCell) { cell in PlannedMealEditor(state: cell) }
            .sheet(isPresented: $showingAssistant) { ChefSheet(dateKey: focusedDateKey) }
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

struct PlannedMealEditor: View {
    @Environment(KitchenStore.self) private var store
    let state: MealCellEditingState

    var body: some View {
        MealEditSheet(state: state, onSave: { value in
            store.updateMeal(value, dateKey: state.dateKey, slot: state.mealSlot)
            store.showToast("已保存")
        }, onDelete: {
            store.updateMeal("", dateKey: state.dateKey, slot: state.mealSlot)
            store.showToast("已清除安排")
        })
    }
}

struct AssistantEntryButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("ZaoWangyeHero")
                    .resizable().scaledToFill()
                    .frame(width: 40, height: 40).clipShape(Circle())
                    .accessibilityHidden(true)
                Text("问问灶王爷").font(.headline)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }
            .padding(16)
            .foregroundStyle(KitchenTheme.brandForeground)
            .background(KitchenTheme.brandCream, in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.md))
        }
        .buttonStyle(KitchenPressStyle())
    }
}

struct ChefSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dateKey: String
    @State private var showingSettings = false

    init(dateKey: String) { _dateKey = State(initialValue: dateKey) }

    var body: some View {
        NavigationStack {
            ScrollView {
                AIChefPanel(planDate: $dateKey,
                            weekDates: DateHelper.weekDates(from: DateHelper.weekStart(for: DateHelper.date(from: dateKey) ?? Date())))
                    .padding()
            }
            .background(KitchenTheme.background)
            .navigationTitle("灶王爷")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("助手设置")
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsSheet() }
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

    private var weekdayLetter: String { DateHelper.weekdayName(for: date) }

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
        .accessibilityLabel("\(DateHelper.monthDayString(date)) \(DateHelper.weekdayName(for: date))")
        .accessibilityValue("\(mealCount) 项安排")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
            Picker("方式", selection: $mode) {
                Text("推荐").tag(AIChefMode.suggest)
                Text("点菜").tag(AIChefMode.input)
            }
            .pickerStyle(.segmented)
            .padding(16)

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
                onAssign: { assignMeal(recipeResult.dish, ingredients: recipeResult.ingredients) },
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
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(KitchenPressStyle())
                .accessibilityLabel("刷新推荐")
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
                onAssign: { assignMeal(suggestion.dish, ingredients: suggestion.ingredients) },
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

    private func assignMeal(_ dish: String, ingredients: [RecipeIngredient] = []) {
        let title = dish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.assignMeal(title, dateKey: planDate, slot: planMeal, ingredients: ingredients)
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
        store.assignMeal(title, dateKey: planDate, slot: planMeal, ingredients: ingredients)
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
                    .foregroundStyle(KitchenTheme.brandForeground)
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
                                .foregroundStyle(KitchenTheme.brandForeground)
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
        HStack(spacing: 8) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: slot.symbolName)
                        .foregroundStyle(KitchenTheme.brandForeground)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(slot.title).font(.caption).foregroundStyle(.secondary)
                        if hasValue {
                            Text(displayValue).font(.subheadline)
                                .strikethrough(isDone)
                                .foregroundStyle(isDone ? .secondary : .primary)
                        }
                    }
                    Spacer()
                    if !hasValue { Image(systemName: "plus") }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑\(slot.title)\(hasValue ? "，" + displayValue : "")")

            if isToday && hasValue {
                Button { onComplete?() } label: {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isDone)
                .accessibilityLabel("完成\(slot.title)")
                .accessibilityValue(isDone ? "已完成" : "未完成")
            }
        }
        .padding(.vertical, 4)
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
    @Environment(\.dynamicTypeSize) private var typeSize
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
                    .foregroundStyle(KitchenTheme.brandForeground)
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
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭编辑")
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
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .onAppear { isFieldFocused = true }
    }
}
