import SwiftUI

struct HomePage: View {
    @Environment(KitchenStore.self) private var store
    @State private var showingSettings = false
    let switchTab: (AppTab) -> Void

    private var todayMeals: [MealSlot: String] {
        store.mealPlans[DateHelper.todayKey] ?? [:]
    }

    private var plannedMealCount: Int {
        todayMeals.values.filter { !$0.isEmpty }.count
    }

    private var projectedBudgetRemaining: Double {
        store.projectedBudgetRemaining
    }

    private var overviewText: String {
        if let first = prioritySummaries.first {
            return "\(first.detail) 需要优先处理。"
        }
        if plannedMealCount == 0 {
            return "今天状态很轻，但菜单还没安排。"
        }
        return "今天一切平稳，照着现有安排推进就可以。"
    }

    private var prioritySummaries: [HomePrioritySummary] {
        var summaries: [HomePrioritySummary] = []

        if !store.alerts.expired.isEmpty {
            summaries.append(
                HomePrioritySummary(
                    title: "过期",
                    detail: previewText(for: store.alerts.expired),
                    count: store.alerts.expired.count,
                    symbol: "exclamationmark.triangle.fill",
                    tint: KitchenTheme.redTint,
                    color: .red,
                    targetTab: .inventory
                )
            )
        }

        if !store.alerts.notFresh.isEmpty {
            summaries.append(
                HomePrioritySummary(
                    title: "不新鲜",
                    detail: previewText(for: store.alerts.notFresh),
                    count: store.alerts.notFresh.count,
                    symbol: "fork.knife.circle.fill",
                    tint: KitchenTheme.redTint,
                    color: .red,
                    targetTab: .mealPlan
                )
            )
        }

        if !store.alerts.expiringSoon.isEmpty {
            summaries.append(
                HomePrioritySummary(
                    title: "将到期",
                    detail: previewText(for: store.alerts.expiringSoon),
                    count: store.alerts.expiringSoon.count,
                    symbol: "clock.fill",
                    tint: KitchenTheme.warnTint,
                    color: .orange,
                    targetTab: .mealPlan
                )
            )
        }

        if !store.alerts.lowStock.isEmpty {
            summaries.append(
                HomePrioritySummary(
                    title: "库存低",
                    detail: previewText(for: store.alerts.lowStock),
                    count: store.alerts.lowStock.count,
                    symbol: "shippingbox.fill",
                    tint: KitchenTheme.greenTint,
                    color: .green,
                    targetTab: .shopping
                )
            )
        }

        return summaries
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Button { switchTab(.mealPlan) } label: {
                        ZaoWangyeCardShell(
                            eyebrow: "智能厨房总管",
                            title: "灶王爷",
                            subtitle: "按库存推荐菜单，顺手补缺货。",
                            imageSize: 162
                        ) {
                            Text(overviewText)
                                .font(.subheadline)
                                .foregroundStyle(KitchenTheme.zaoCream.opacity(0.92))

                            HStack(spacing: 10) {
                                ZaoWangyeStatPill(
                                    symbol: "menucard.fill",
                                    title: "今日菜单",
                                    value: plannedMealCount == 0 ? "待安排" : "\(plannedMealCount) 项"
                                )

                                ZaoWangyeStatPill(
                                    symbol: "cart.fill",
                                    title: "待购",
                                    value: "\(store.pendingShoppingCount) 项",
                                    accent: KitchenTheme.zaoMint
                                )
                            }

                            HStack(spacing: 10) {
                                Label("打开灶王爷", systemImage: "sparkles")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(projectedBudgetRemaining >= 0 ? "预算余量 \(projectedBudgetRemaining.currencyText)" : "超支 \(abs(projectedBudgetRemaining).currencyText)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(KitchenTheme.zaoCream.opacity(0.88))
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(KitchenTheme.zaoGold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .padding(.horizontal)

                    // Priority alerts
                    if prioritySummaries.isEmpty {
                        NoAlertCard()
                            .padding(.horizontal)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("优先处理")
                                    .font(.headline)
                                Spacer()
                                Text("\(store.alertCount) 条提醒")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(Array(prioritySummaries.prefix(3))) { summary in
                                HomePriorityRow(summary: summary) {
                                    switchTab(summary.targetTab)
                                }
                            }
                        }
                        .cardStyle()
                        .padding(.horizontal)
                    }

                    // Today's meal schedule
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("今日安排")
                                .font(.headline)
                            Spacer()
                            Button { switchTab(.mealPlan) } label: {
                                Text("本周")
                                    .font(.caption.weight(.medium))
                            }
                        }

                        let planned = MealSlot.allCases.filter { todayMeals[$0]?.isEmpty == false }
                        if planned.isEmpty {
                            Button { switchTab(.mealPlan) } label: {
                                HStack {
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(Color.accentColor)
                                    Text("还没安排今天的菜单")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        } else {
                            ForEach(planned) { slot in
                                let meal = todayMeals[slot] ?? ""
                                let isDone = meal.hasPrefix("✅")
                                let displayName = isDone ? String(meal.dropFirst(2)) : meal
                                HStack(spacing: 10) {
                                    Button {
                                        if !isDone {
                                            store.completeMeal(dateKey: DateHelper.todayKey, slot: slot)
                                            store.showToast("\(slot.title) 已完成")
                                        }
                                    } label: {
                                        Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(isDone ? .green : Color(.tertiaryLabel))
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(slot.title)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.secondary)
                                        Text(displayName)
                                            .font(.subheadline)
                                            .strikethrough(isDone)
                                            .foregroundStyle(isDone ? .secondary : .primary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            .background(KitchenTheme.background)
            .navigationTitle("今天 \(DateHelper.monthDayString(Date()))")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet()
            }
        }
    }

    private func previewText(for items: [AlertItem]) -> String {
        let names = items.prefix(2).map { shortLabel($0.label) }
        let extraCount = max(items.count - names.count, 0)
        let summary = names.joined(separator: "、")
        return extraCount > 0 ? "\(summary) +\(extraCount)" : summary
    }

    private func shortLabel(_ label: String) -> String {
        label
            .components(separatedBy: "（")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? label
    }
}

// MARK: - Supporting Views

private struct HomePrioritySummary: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let count: Int
    let symbol: String
    let tint: Color
    let color: Color
    let targetTab: AppTab
}

private struct HomePriorityRow: View {
    let summary: HomePrioritySummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: summary.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(summary.color)
                    .frame(width: 32, height: 32)
                    .background(summary.tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.title)
                        .font(.subheadline.weight(.semibold))
                    Text(summary.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(summary.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(summary.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(summary.tint, in: Capsule())
            }
        }
        .buttonStyle(.plain)
    }
}

