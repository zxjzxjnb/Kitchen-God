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
                Button(action: action) { content.frame(minHeight: 44).contentShape(Rectangle()) }
                    .buttonStyle(KitchenPressStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        case .tinted, .outlined: return color == KitchenTheme.brandCrimson ? KitchenTheme.brandForeground : color
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
        .tint(KitchenTheme.brandForeground)
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

// MARK: - Shopping Item Row

struct ShoppingItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    var shopDays: [String] = []
    var onAssign: ((String) -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isChecked ? KitchenTheme.brandForeground : KitchenTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name).font(.subheadline)
                            .strikethrough(item.isChecked)
                        Text("\(item.quantity)\(item.unit) · 约 \(item.estimatedTotalCost.currencyText)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(item.isChecked ? KitchenTheme.textSecondary : KitchenTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.name)，\(item.quantity)\(item.unit)")
            .accessibilityValue(item.isChecked ? "已勾选" : "未勾选")
            Menu {
                if let onAssign {
                    Menu("购物日") {
                        Button("未分配") { onAssign("") }
                        ForEach(shopDays, id: \.self) { day in
                            Button(day == DateHelper.todayKey ? "今天" : day) { onAssign(day) }
                        }
                    }
                }
                Button("删除", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(item.name)的操作")
        }
        .padding(.vertical, 8)
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
