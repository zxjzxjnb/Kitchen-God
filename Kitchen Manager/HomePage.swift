import SwiftUI

struct HomePage: View {
    @Environment(KitchenStore.self) private var store
    @State private var showingSettings = false
    let switchTab: (AppTab) -> Void

    private let mealSlots: [MealSlot] = [.breakfast, .lunch, .dinner]

    private var todayMeals: [MealSlot: String] {
        store.mealPlans[DateHelper.todayKey] ?? [:]
    }

    private var plannedMealCount: Int {
        mealSlots.filter { todayMeals[$0]?.isEmpty == false }.count
    }

    private var projectedBudgetRemaining: Double {
        store.projectedBudgetRemaining
    }

    private var quickPrompts: [String] {
        ["低预算晚餐", "用临期食材", "清冰箱菜单"]
    }

    private var homeRecommendation: HomeRecommendation? {
        let alerts = store.alerts

        if let item = firstInventoryItem(matching: alerts.expired) {
            return recommendation(for: item, issue: .expired)
        }
        if let item = firstInventoryItem(matching: alerts.notFresh) {
            return recommendation(for: item, issue: .notFresh)
        }
        if let item = firstInventoryItem(matching: alerts.expiringSoon) {
            return recommendation(for: item, issue: .expiringSoon)
        }
        if let item = firstInventoryItem(matching: alerts.lowStock) {
            return recommendation(for: item, issue: .lowStock)
        }
        if let item = store.inventoryItems.first {
            return recommendation(for: item, issue: .steady)
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZaoWangyeCardShell(
                        eyebrow: "灶王爷 AI",
                        title: "问问灶王爷",
                        subtitle: "今晚想吃什么？",
                        imageSize: 118
                    ) {
                        Button { switchTab(.mealPlan) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(KitchenTheme.brandCrimson)
                                    .frame(width: 30, height: 30)
                                    .background(KitchenTheme.brandCrimson.opacity(0.10), in: Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("打开完整助手")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(KitchenTheme.textPrimary)
                                    Text("点菜、生成菜谱、同步待购食材")
                                        .font(.caption)
                                        .foregroundStyle(KitchenTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(KitchenTheme.brandCrimson)
                            }
                            .padding(KitchenTheme.Spacing.md)
                            .background(
                                KitchenTheme.surfaceElevated,
                                in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.md + 2, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: KitchenTheme.Radius.md + 2, style: .continuous)
                                    .strokeBorder(KitchenTheme.separator.opacity(0.45), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(KitchenPressStyle())

                        HStack(spacing: 8) {
                            ForEach(quickPrompts, id: \.self) { prompt in
                                KitchenChip(title: prompt, style: .tinted, color: KitchenTheme.brandCrimson) {
                                    switchTab(.mealPlan)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    HStack(spacing: 10) {
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
                            title: projectedBudgetRemaining >= 0 ? "预算余量" : "已超支",
                            value: projectedBudgetRemaining >= 0 ? projectedBudgetRemaining.currencyText : abs(projectedBudgetRemaining).currencyText,
                            symbol: projectedBudgetRemaining >= 0 ? "banknote.fill" : "exclamationmark.triangle.fill",
                            accent: projectedBudgetRemaining >= 0 ? KitchenTheme.brandGold : KitchenTheme.danger
                        ) {
                            switchTab(.budget)
                        }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("今日安排")
                                .font(.headline)
                            Spacer()
                            Button { switchTab(.mealPlan) } label: {
                                Text(plannedMealCount == 0 ? "去安排" : "本周")
                                    .font(.caption.weight(.medium))
                            }
                        }

                        VStack(spacing: 8) {
                            ForEach(mealSlots) { slot in
                                HomeMealRow(
                                    slot: slot,
                                    meal: todayMeals[slot],
                                    onEdit: { switchTab(.mealPlan) },
                                    onComplete: {
                                        store.completeMeal(dateKey: DateHelper.todayKey, slot: slot)
                                        store.showToast("好,这顿\(slot.title)吃完了。", kind: .success)
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

                    if let recommendation = homeRecommendation {
                        HomeRecommendationCard(recommendation: recommendation) {
                            switchTab(.mealPlan)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(KitchenTheme.background)
            .navigationTitle("今天 \(DateHelper.monthDayString(Date()))")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    KitchenBrandMark()
                }
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

    private func firstInventoryItem(matching alerts: [AlertItem]) -> InventoryItem? {
        for alert in alerts {
            if let item = store.inventoryItems.first(where: { $0.id == alert.id }) {
                return item
            }
        }
        return nil
    }

    private func recommendation(for item: InventoryItem, issue: HomeRecommendationIssue) -> HomeRecommendation {
        HomeRecommendation(
            dish: recommendedDish(for: item, issue: issue),
            reason: recommendationReason(for: item, issue: issue),
            ingredientName: item.name,
            issueTitle: issue.title,
            symbol: issue.symbol,
            accent: issue.accent
        )
    }

    private func recommendedDish(for item: InventoryItem, issue: HomeRecommendationIssue) -> String {
        let name = KitchenData.normalizedIngredientName(item.name)

        if issue == .expired {
            return "确认\(item.name)"
        }
        if issue == .lowStock {
            return "补齐\(item.name)"
        }
        if name.contains("番茄") || name.contains("西红柿") {
            return "番茄鸡蛋面"
        }
        if name.contains("豆腐") {
            return "菌菇豆腐汤"
        }
        if name.contains("鸡胸肉") || name.contains("鸡肉") {
            return "香煎鸡胸肉"
        }
        if name.contains("牛奶") {
            return "燕麦牛奶杯"
        }
        if name.contains("土豆") || name.contains("马铃薯") {
            return "土豆炖牛肉"
        }
        if item.category == "蔬菜" {
            return "\(item.name)快手菜"
        }
        if item.category == "肉类" || item.category == "海鲜" {
            return "\(item.name)主菜"
        }
        return item.usageSuggestion.isEmpty ? "清冰箱晚餐" : item.usageSuggestion
    }

    private func recommendationReason(for item: InventoryItem, issue: HomeRecommendationIssue) -> String {
        switch issue {
        case .expired:
            return "\(item.name)已经过期，建议先确认能否处理。"
        case .notFresh:
            return "\(item.name)新鲜度下降，适合今天安排掉。"
        case .expiringSoon:
            return "\(item.name)快到期，优先放进今晚菜单。"
        case .lowStock:
            return "\(item.name)库存偏低，下次采购可以补上。"
        case .steady:
            return "库存状态平稳，可以按现有食材安排一餐。"
        }
    }
}

// MARK: - Supporting Views

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
                        .lineLimit(1)

                    Text(value)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(KitchenTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
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
                    .font(.title3)
                    .foregroundStyle(isDone ? KitchenTheme.brandGold : KitchenTheme.brandCrimson)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

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
                            .lineLimit(1)
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

private struct HomeHydrationRow: View {
    let amountML: Int
    let goalML: Int
    let onAddWater: () -> Void

    private var safeGoalML: Int {
        max(goalML, 1)
    }

    private var progress: Double {
        min(Double(amountML) / Double(safeGoalML), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "drop.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 30, height: 30)
                    .background(Color.blue.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("今日饮水")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KitchenTheme.textPrimary)
                    Text("\(amountML) / \(safeGoalML) ml")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(KitchenTheme.textSecondary)
                }

                Spacer()

                Button("+250ml", action: onAddWater)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KitchenTheme.brandCrimson)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(KitchenTheme.brandCrimson.opacity(0.08), in: Capsule())
            }

            ProgressView(value: progress)
                .tint(KitchenTheme.brandCrimson)
        }
        .padding(.vertical, 2)
    }
}

private struct HomeRecommendationCard: View {
    let recommendation: HomeRecommendation
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("灶王爷推荐")
                    .font(.headline)
                Spacer()
                Text(recommendation.issueTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(recommendation.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(recommendation.accent.opacity(0.10), in: Capsule())
            }

            HStack(alignment: .top, spacing: 12) {
                Image("ZaoWangyeHero")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(KitchenTheme.brandGold.opacity(0.65), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.dish)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(KitchenTheme.textPrimary)
                        .lineLimit(2)

                    Text(recommendation.reason)
                        .font(.subheadline)
                        .foregroundStyle(KitchenTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Label("关联食材：\(recommendation.ingredientName)", systemImage: recommendation.symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(recommendation.accent)
                }
            }

            Button(action: action) {
                HStack {
                    Label("去菜单页查看", systemImage: "menucard.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3.weight(.semibold))
                }
                .foregroundStyle(KitchenTheme.brandCrimson)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    KitchenTheme.brandCrimson.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.md, style: .continuous)
                )
            }
            .buttonStyle(KitchenPressStyle())
        }
        .cardStyle()
    }
}

private struct HomeRecommendation {
    let dish: String
    let reason: String
    let ingredientName: String
    let issueTitle: String
    let symbol: String
    let accent: Color
}

private enum HomeRecommendationIssue {
    case expired
    case notFresh
    case expiringSoon
    case lowStock
    case steady

    var title: String {
        switch self {
        case .expired: return "先确认"
        case .notFresh: return "今天处理"
        case .expiringSoon: return "快到期"
        case .lowStock: return "待补货"
        case .steady: return "可安排"
        }
    }

    var symbol: String {
        switch self {
        case .expired: return "exclamationmark.triangle.fill"
        case .notFresh: return "fork.knife.circle.fill"
        case .expiringSoon: return "clock.fill"
        case .lowStock: return "shippingbox.fill"
        case .steady: return "checkmark.seal.fill"
        }
    }

    var accent: Color {
        switch self {
        case .expired, .notFresh: return KitchenTheme.danger
        case .expiringSoon: return KitchenTheme.warning
        case .lowStock: return KitchenTheme.brandCrimson
        case .steady: return KitchenTheme.success
        }
    }
}
