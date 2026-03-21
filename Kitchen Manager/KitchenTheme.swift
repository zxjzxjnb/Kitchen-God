import SwiftUI

enum KitchenTheme {
    // MARK: - Semantic Colors (auto Dark Mode)
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let surfaceElevated = Color(.systemBackground)

    static let green = Color.green
    static let greenTint = Color.green.opacity(0.12)
    static let accent = Color.accentColor
    static let accentTint = Color.accentColor.opacity(0.10)
    static let red = Color.red
    static let redTint = Color.red.opacity(0.12)
    static let warn = Color.orange
    static let warnTint = Color.orange.opacity(0.12)
    static let gold = Color.yellow

    static let text = Color.primary
    static let subtleText = Color.secondary
    static let mutedText = Color(.tertiaryLabel)
    static let border = Color(.separator)
    static let borderSoft = Color(.quaternarySystemFill)
}

// MARK: - Card ViewModifier

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KitchenTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
