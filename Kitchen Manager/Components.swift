import SwiftUI

// MARK: - Category Tag (legacy compat — prefer KitchenChip)

struct CategoryTag: View {
    let title: String
    let tint: Color
    let textColor: Color

    var body: some View {
        Text(title)
            .font(KitchenType.eyebrow)
            .foregroundStyle(textColor)
            .padding(.horizontal, KitchenTheme.Spacing.sm)
            .padding(.vertical, 3)
            .background(tint, in: Capsule())
    }
}

// MARK: - KitchenChip (unified replacement for inline pill / chip / tag)

struct KitchenChip: View {
    enum Style { case filled, tinted, outlined }

    let title: String
    var style: Style = .tinted
    var color: Color = KitchenTheme.brandCrimson
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) { content }
                    .buttonStyle(KitchenPressStyle())
            } else {
                content
            }
        }
    }

    private var content: some View {
        Text(title)
            .font(KitchenType.detail.weight(.semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, KitchenTheme.Spacing.md)
            .padding(.vertical, 6)
            .background(background, in: Capsule())
            .overlay(
                Capsule().stroke(borderColor, lineWidth: borderWidth)
            )
    }

    private var textColor: Color {
        switch style {
        case .filled:   return .white
        case .tinted, .outlined: return color
        }
    }

    private var background: Color {
        switch style {
        case .filled:   return color
        case .tinted:   return color.opacity(0.10)
        case .outlined: return .clear
        }
    }

    private var borderColor: Color {
        if isSelected { return KitchenTheme.brandGold.opacity(0.55) }
        return style == .outlined ? color.opacity(0.35) : .clear
    }

    private var borderWidth: CGFloat {
        if isSelected { return 1.2 }
        return style == .outlined ? 1 : 0
    }
}

// MARK: - Page Header

struct KitchenMetric: Identifiable {
    let title: String
    let value: String
    let symbol: String
    let accent: Color

    var id: String { title }
}

struct KitchenPageHeader: View {
    let eyebrow: String
    let title: String
    let message: String
    let symbol: String
    let accent: Color
    let metrics: [KitchenMetric]
    var actionTitle: String?
    var actionSymbol: String?
    var action: (() -> Void)?

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 118), spacing: KitchenTheme.Spacing.md)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KitchenTheme.Spacing.lg) {
            HStack(alignment: .top, spacing: KitchenTheme.Spacing.md) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(KitchenTheme.brandCrimson)
                    .frame(width: 42, height: 42)
                    .background(KitchenTheme.brandCrimson.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(eyebrow)
                        .font(KitchenType.eyebrow)
                        .kerning(0.5)
                        .foregroundStyle(KitchenTheme.brandCrimson)
                        .padding(.horizontal, KitchenTheme.Spacing.sm)
                        .padding(.vertical, KitchenTheme.Spacing.xs)
                        .background(KitchenTheme.brandCrimson.opacity(0.08), in: Capsule())

                    Text(title)
                        .font(KitchenType.title)
                        .foregroundStyle(KitchenTheme.textPrimary)

                    Text(message)
                        .font(KitchenType.body)
                        .foregroundStyle(KitchenTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(columns: metricColumns, spacing: KitchenTheme.Spacing.md) {
                ForEach(metrics) { metric in
                    KitchenMetricTile(metric: metric)
                }
            }

            if let actionTitle, let actionSymbol, let action {
                Button(action: action) {
                    HStack(spacing: KitchenTheme.Spacing.sm) {
                        Label(actionTitle, systemImage: actionSymbol)
                            .font(KitchenType.body.weight(.semibold))
                        Spacer(minLength: KitchenTheme.Spacing.sm)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3.weight(.semibold))
                    }
                    .foregroundStyle(KitchenTheme.brandCrimson)
                    .padding(.horizontal, KitchenTheme.Spacing.md + 2)
                    .padding(.vertical, 11)
                    .background(
                        KitchenTheme.brandCrimson.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: KitchenTheme.panelRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: KitchenTheme.panelRadius, style: .continuous)
                            .stroke(KitchenTheme.brandCrimson.opacity(0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(KitchenPressStyle())
            }
        }
        .padding(KitchenTheme.Spacing.lg + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            KitchenTheme.brandCream,
            in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.lg, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTheme.Radius.lg, style: .continuous)
                .strokeBorder(KitchenTheme.brandGold.opacity(0.25), lineWidth: 1)
        )
        .kitchenShadow()
    }
}

private struct KitchenMetricTile: View {
    let metric: KitchenMetric

    var body: some View {
        HStack(alignment: .center, spacing: KitchenTheme.Spacing.sm) {
            Image(systemName: metric.symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(metric.accent)
                .frame(width: 28, height: 28)
                .background(metric.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(metric.title)
                    .font(KitchenType.detail)
                    .foregroundStyle(KitchenTheme.textSecondary)
                    .lineLimit(1)

                Text(metric.value)
                    .font(KitchenType.metric)
                    .foregroundStyle(KitchenTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, KitchenTheme.Spacing.md)
        .padding(.vertical, KitchenTheme.Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            KitchenTheme.surfaceElevated,
            in: RoundedRectangle(cornerRadius: KitchenTheme.panelRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTheme.panelRadius, style: .continuous)
                .stroke(KitchenTheme.separator.opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - Form Field

struct FormField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(KitchenType.detail.weight(.medium))
                .foregroundStyle(KitchenTheme.textSecondary)
            content
        }
    }
}

// MARK: - Buttons

struct FilledButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KitchenType.body.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(KitchenTheme.brandCrimson)
        .controlSize(.large)
    }
}

struct SecondaryButton: View {
    let title: String
    var symbol: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(KitchenType.body.weight(.semibold))
                }
                Text(title)
                    .font(KitchenType.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(KitchenTheme.brandCrimson)
        .controlSize(.large)
    }
}

struct IconButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(KitchenType.body.weight(.medium))
                .foregroundStyle(KitchenTheme.textSecondary)
        }
        .buttonStyle(KitchenPressStyle())
        .contentShape(Circle())
    }
}

// MARK: - Loading

struct LoadingRow: View {
    let text: String

    var body: some View {
        HStack(spacing: KitchenTheme.Spacing.sm) {
            ProgressView()
            Text(text)
                .font(KitchenType.body)
                .foregroundStyle(KitchenTheme.textSecondary)
        }
    }
}

// MARK: - Card

struct KitchenCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: KitchenTheme.Spacing.md) {
            content
        }
        .cardStyle()
    }
}

// MARK: - Flow Layout (legacy no-op stub — left for compat)

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Toast

enum ToastKind {
    case info, success, warning, error

    var symbol: String {
        switch self {
        case .info:    return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "xmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .info:    return KitchenTheme.brandCrimson
        case .success: return KitchenTheme.brandGold
        case .warning: return KitchenTheme.warning
        case .error:   return KitchenTheme.danger
        }
    }
}

struct ToastView: View {
    let message: String
    var kind: ToastKind = .info

    var body: some View {
        HStack(spacing: KitchenTheme.Spacing.sm) {
            Image(systemName: kind.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(kind.iconColor)
            Text(message)
                .font(KitchenType.body.weight(.semibold))
                .foregroundStyle(KitchenTheme.textPrimary)
        }
        .padding(.horizontal, KitchenTheme.Spacing.lg + 2)
        .padding(.vertical, KitchenTheme.Spacing.md)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                kind == .success ? KitchenTheme.brandGold.opacity(0.45) : Color.clear,
                lineWidth: 1
            )
        )
        .kitchenShadow()
    }
}

// MARK: - Empty State

struct EmptyStateCard: View {
    let symbol: String
    let title: String
    let subtitle: String?
    var imageName: String? = nil

    var body: some View {
        KitchenCard {
            VStack(spacing: KitchenTheme.Spacing.sm) {
                if let imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .padding(.top, KitchenTheme.Spacing.xs)
                } else {
                    Image(systemName: symbol)
                        .font(.title)
                        .foregroundStyle(KitchenTheme.textTertiary)
                        .padding(.top, KitchenTheme.Spacing.xs)
                }
                Text(title)
                    .font(KitchenType.section)
                    .foregroundStyle(KitchenTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(KitchenType.body)
                        .foregroundStyle(KitchenTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, KitchenTheme.Spacing.sm)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Budget Stat

struct BudgetStatCard: View {
    let title: String
    let value: String
    let tint: Color
    var symbol: String? = nil
    var accent: Color = KitchenTheme.brandGold

    var body: some View {
        VStack(alignment: .leading, spacing: KitchenTheme.Spacing.sm + 2) {
            HStack(spacing: KitchenTheme.Spacing.sm) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .frame(width: 24, height: 24)
                        .background(accent.opacity(0.12), in: Circle())
                }

                Text(title)
                    .font(KitchenType.detail.weight(.medium))
                    .foregroundStyle(KitchenTheme.textSecondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(KitchenType.metric)
                .foregroundStyle(KitchenTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(KitchenTheme.Spacing.md + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint, in: RoundedRectangle(cornerRadius: KitchenTheme.panelRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTheme.panelRadius, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Alert Cards

struct AlertCard: View {
    let title: String
    let symbol: String
    let tint: Color
    let stroke: Color
    let items: [AlertItem]

    var body: some View {
        VStack(alignment: .leading, spacing: KitchenTheme.Spacing.sm) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(stroke)

            FlowLayout(spacing: 6) {
                ForEach(items) { item in
                    Text(item.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stroke)
                        .padding(.horizontal, KitchenTheme.Spacing.sm)
                        .padding(.vertical, KitchenTheme.Spacing.xs)
                        .background(tint, in: Capsule())
                }
            }
        }
        .padding(KitchenTheme.Spacing.md)
        .background(KitchenTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct NoAlertCard: View {
    var body: some View {
        HStack(spacing: KitchenTheme.Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(KitchenTheme.brandGold)
            VStack(alignment: .leading, spacing: 2) {
                Text("一切正常")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KitchenTheme.textPrimary)
                Text("暂无到期提醒,库存充足。")
                    .font(KitchenType.detail)
                    .foregroundStyle(KitchenTheme.textSecondary)
            }
            Spacer()
        }
        .padding(KitchenTheme.Spacing.md + 2)
        .background(
            KitchenTheme.surfaceElevated,
            in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.md, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTheme.Radius.md, style: .continuous)
                .stroke(KitchenTheme.brandGold.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Shopping Item Row

struct ShoppingItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: KitchenTheme.Spacing.sm) {
            Button(action: onToggle) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? KitchenTheme.brandGold : KitchenTheme.textTertiary)
            }
            .buttonStyle(KitchenPressStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(KitchenType.body)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? KitchenTheme.textSecondary : KitchenTheme.textPrimary)

                HStack(spacing: 6) {
                    if !item.quantity.isEmpty {
                        Text("\(item.quantity)\(item.unit)")
                            .font(KitchenType.detail)
                            .foregroundStyle(KitchenTheme.textSecondary)
                    }
                    Text("约 \(item.estimatedTotalCost.currencyText)")
                        .font(KitchenType.detail.weight(.medium))
                        .foregroundStyle(item.isChecked ? KitchenTheme.textTertiary : KitchenTheme.textSecondary)
                }
            }

            Spacer()

            CategoryTag(
                title: item.category,
                tint: KitchenTheme.brandCrimson.opacity(0.08),
                textColor: KitchenTheme.brandCrimson
            )
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
        .sensoryFeedback(.selection, trigger: item.isChecked)
    }
}

// MARK: - Day Chip

struct DayChip: View {
    let weekday: String
    let dayText: String
    let badgeCount: Int
    let isSelected: Bool
    let isToday: Bool
    var accent: Color = .accentColor
    var minHeight: CGFloat = 52
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(weekday)
                    .font(KitchenType.eyebrow)
                Text(dayText)
                    .font(.subheadline.weight(.bold))
                if badgeCount > 0 {
                    Text("\(badgeCount)项")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(badgeColor)
                }
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background {
                RoundedRectangle(cornerRadius: KitchenTheme.Radius.md, style: .continuous)
                    .fill(backgroundColor)
            }
            .overlay(
                RoundedRectangle(cornerRadius: KitchenTheme.Radius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .overlay(alignment: .top) {
                if isToday && !isSelected {
                    Circle()
                        .fill(KitchenTheme.brandGold)
                        .frame(width: 4, height: 4)
                        .padding(.top, 4)
                }
            }
        }
        .buttonStyle(KitchenPressStyle())
    }

    private var textColor: Color {
        isSelected ? .white : KitchenTheme.textPrimary
    }

    private var badgeColor: Color {
        isSelected ? Color.white.opacity(0.9) : KitchenTheme.textTertiary
    }

    private var backgroundColor: Color {
        if isSelected { return KitchenTheme.brandCrimson }
        if isToday    { return KitchenTheme.brandGold.opacity(0.10) }
        return Color(.tertiarySystemFill)
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

// MARK: - Plan Selector

struct PlanSelector: View {
    @Binding var planDate: String
    @Binding var planMeal: MealSlot
    let weekDates: [Date]

    var body: some View {
        HStack(spacing: KitchenTheme.Spacing.sm) {
            Picker("日期", selection: $planDate) {
                ForEach(weekDates, id: \.self) { date in
                    let key = DateHelper.key(for: date)
                    Text("\(DateHelper.weekdayName(for: date)) \(DateHelper.monthDayString(date))").tag(key)
                }
            }
            .pickerStyle(.menu)

            Picker("餐次", selection: $planMeal) {
                ForEach(MealSlot.allCases) { slot in
                    Label(slot.title, systemImage: slot.symbolName).tag(slot)
                }
            }
            .pickerStyle(.menu)
        }
    }
}
