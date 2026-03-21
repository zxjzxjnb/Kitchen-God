import SwiftUI

// MARK: - Category Tag

struct CategoryTag: View {
    let title: String
    let tint: Color
    let textColor: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint, in: Capsule())
    }
}

// MARK: - Form Field

struct FormField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
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
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
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
                        .font(.subheadline.weight(.semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

struct IconButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

// MARK: - Loading

struct LoadingRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Card

struct KitchenCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .cardStyle()
    }
}

// MARK: - Flow Layout

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

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }
}

// MARK: - Empty State

struct EmptyStateCard: View {
    let symbol: String
    let title: String
    let subtitle: String?

    var body: some View {
        KitchenCard {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Budget Stat

struct BudgetStatCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(stroke)

            FlowLayout(spacing: 6) {
                ForEach(items) { item in
                    Text(item.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stroke)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tint, in: Capsule())
                }
            }
        }
        .padding(12)
        .background(KitchenTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct NoAlertCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("一切正常")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                Text("暂无到期提醒，库存充足。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(KitchenTheme.greenTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Shopping Item Row

struct ShoppingItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Color.green : Color(.tertiaryLabel))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)

                HStack(spacing: 6) {
                    if !item.quantity.isEmpty {
                        Text("\(item.quantity)\(item.unit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("约 \(item.estimatedTotalCost.currencyText)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(item.isChecked ? Color(.tertiaryLabel) : Color.accentColor)
                }
            }

            Spacer()

            CategoryTag(title: item.category, tint: KitchenTheme.greenTint, textColor: .green)
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// MARK: - Plan Selector

struct PlanSelector: View {
    @Binding var planDate: String
    @Binding var planMeal: MealSlot
    let weekDates: [Date]

    var body: some View {
        HStack(spacing: 8) {
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
