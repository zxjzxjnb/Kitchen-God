import SwiftUI

struct HomePage: View {
    @Environment(KitchenStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showingSettings = false
    @State private var showingAssistant = false
    @State private var editingCell: MealCellEditingState?
    let switchTab: (AppTab) -> Void

    private let mealSlots: [MealSlot] = [.breakfast, .lunch, .dinner]
    private var todayMeals: [MealSlot: String] { store.mealPlans[DateHelper.todayKey] ?? [:] }
    private var projectedBudgetRemaining: Double { store.projectedBudgetRemaining }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("今日安排")
                                .font(.headline)
                            Spacer()
                            Button { switchTab(.mealPlan) } label: {
                                Text("菜单")
                                    .font(.caption.weight(.medium))
                                    .frame(minHeight: 44)
                            }
                        }

                        VStack(spacing: 8) {
                            ForEach(mealSlots) { slot in
                                HomeMealRow(
                                    slot: slot,
                                    meal: todayMeals[slot],
                                    onEdit: { editingCell = MealCellEditingState(dateKey: DateHelper.todayKey, mealSlot: slot, value: todayMeals[slot] ?? "") },
                                    onComplete: {
                                        let deducted = store.completeMeal(dateKey: DateHelper.todayKey, slot: slot)
                                        store.showToast(
                                            deducted ? "好,这顿\(slot.title)吃完了,库存也更新了。" : "这顿\(slot.title)记下了；没有可扣减的库存。",
                                            kind: deducted ? .success : .warning
                                        )
                                    }
                                )
                            }
                        }

                        Divider()

                        HomeHydrationRow(
                            amountML: store.todayHydrationAmountML,
                            goalML: store.dailyWaterGoalML,
                            onAddWater: {
                                store.addHydration(amountML: 250, drinkName: "水")
                            }
                        )
                    }
                    .cardStyle()
                    .padding(.horizontal)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: typeSize.isAccessibilitySize ? 1 : 3), spacing: 10) {
                        HomeMetricPill(
                            title: "提醒",
                            value: "\(store.alertCount)",
                            symbol: store.alertCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                            accent: store.alertCount == 0 ? KitchenTheme.success : KitchenTheme.warning
                        ) {
                            switchTab(.inventory)
                        }

                        HomeMetricPill(
                            title: "待购",
                            value: "\(store.pendingShoppingCount)",
                            symbol: "cart.fill",
                            accent: KitchenTheme.brandCrimson
                        ) {
                            switchTab(.shopping)
                        }

                        HomeMetricPill(
                            title: projectedBudgetRemaining >= 0 ? "预计可用" : "预计超支",
                            value: projectedBudgetRemaining >= 0 ? projectedBudgetRemaining.currencyText : abs(projectedBudgetRemaining).currencyText,
                            symbol: projectedBudgetRemaining >= 0 ? "banknote.fill" : "exclamationmark.triangle.fill",
                            accent: projectedBudgetRemaining >= 0 ? KitchenTheme.brandGold : KitchenTheme.danger
                        ) {
                            switchTab(.budget)
                        }
                    }
                    .padding(.horizontal)

                    AssistantEntryButton { showingAssistant = true }
                        .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            .background(KitchenTheme.background)
            .navigationTitle("今天 \(DateHelper.monthDayString(Date()))")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("设置")
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsSheet() }
            .sheet(isPresented: $showingAssistant) { ChefSheet(dateKey: DateHelper.todayKey) }
            .sheet(item: $editingCell) { cell in PlannedMealEditor(state: cell) }
        }
    }
}

private struct HomeMetricPill: View {
    let title: String
    let value: String
    let symbol: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 26, height: 26)
                    .background(accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(KitchenTheme.textSecondary)

                    Text(value)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(KitchenTheme.textPrimary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(
                KitchenTheme.surfaceElevated,
                in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: KitchenTheme.Radius.md, style: .continuous)
                    .strokeBorder(KitchenTheme.separator.opacity(0.45), lineWidth: 0.5)
            )
        }
        .buttonStyle(KitchenPressStyle())
    }
}

private struct HomeMealRow: View {
    let slot: MealSlot
    let meal: String?
    let onEdit: () -> Void
    let onComplete: () -> Void

    private var trimmedMeal: String {
        meal?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var isDone: Bool {
        trimmedMeal.hasPrefix("✅")
    }

    private var displayName: String {
        isDone ? String(trimmedMeal.dropFirst(2)) : trimmedMeal
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if trimmedMeal.isEmpty {
                    onEdit()
                } else if !isDone {
                    onComplete()
                }
            } label: {
                Image(systemName: trimmedMeal.isEmpty ? "plus.circle" : (isDone ? "checkmark.circle.fill" : "circle"))
                    .font(.system(size: 22))
                    .foregroundStyle(isDone ? KitchenTheme.brandGold : KitchenTheme.brandForeground)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isDone)
            .accessibilityLabel(trimmedMeal.isEmpty ? "安排\(slot.title)" : "完成\(slot.title)")
            .accessibilityValue(isDone ? "已完成" : "")

            Button(action: onEdit) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(slot.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(KitchenTheme.textSecondary)

                        Text(displayName.isEmpty ? "待安排" : displayName)
                            .font(.subheadline)
                            .strikethrough(isDone)
                            .foregroundStyle(displayName.isEmpty ? KitchenTheme.textTertiary : (isDone ? KitchenTheme.textSecondary : KitchenTheme.textPrimary))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑\(slot.title)，\(displayName.isEmpty ? "未安排" : displayName)")
        }
        .padding(.vertical, 2)
    }
}

private struct HomeHydrationRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let amountML: Int
    let goalML: Int
    let onAddWater: () -> Void

    private var safeGoalML: Int { max(goalML, 1) }
    private var progress: Double { min(Double(amountML) / Double(safeGoalML), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if typeSize.isAccessibilitySize {
                hydrationAmount
                addWaterButton
            } else {
                HStack(spacing: 10) {
                    hydrationAmount
                    Spacer()
                    addWaterButton
                }
            }
            ProgressView(value: progress).tint(KitchenTheme.brandForeground)
        }
        .padding(.vertical, 2)
    }

    private var hydrationAmount: some View {
        HStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(Color.blue.opacity(0.10), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("饮水").font(.subheadline.weight(.semibold))
                Text("\(amountML) / \(safeGoalML) ml")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var addWaterButton: some View {
        Button("+250ml", action: onAddWater)
            .font(.caption.weight(.semibold))
            .foregroundStyle(KitchenTheme.brandForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(KitchenTheme.brandCrimson.opacity(0.08), in: Capsule())
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("记录饮水 250 毫升")
    }
}
