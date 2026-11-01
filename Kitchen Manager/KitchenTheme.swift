import SwiftUI

// MARK: - KitchenTheme
//
// Design tokens for the Kitchen Manager app.
//
// Brand model: 灶王爷 ("Kitchen God") shows up as a low-key persistent presence —
// crimson primary + cream surfaces + gold reserved for ~5% ceremonial moments
// (selection / completion). Everything else follows iOS HIG (system surfaces,
// system semantic colors, Dynamic Type, soft neutral shadow).

enum KitchenTheme {

    // MARK: Brand (4)

    static let brandCrimson = Color("BrandCrimson")
    static let brandForeground = Color("BrandForeground")
    static let brandAmber   = Color("BrandAmber")
    static let brandGold    = Color("BrandGold")
    static let brandCream   = Color("BrandCream")

    // MARK: Surfaces (system)

    static let background      = Color(.systemGroupedBackground)
    static let surface         = Color(.secondarySystemGroupedBackground)
    static let surfaceElevated = Color(.systemBackground)

    // MARK: Semantic (system)

    static let success = Color.green
    static let warning = Color.orange
    static let danger  = Color.red

    // MARK: Text (system)

    static let textPrimary   = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary  = Color(.tertiaryLabel)
    static let separator     = Color(.separator)

    // MARK: Layout

    static let pagePadding:  CGFloat = Spacing.lg
    static let cardRadius:   CGFloat = Radius.lg
    static let panelRadius:  CGFloat = Radius.md

    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }
}

// MARK: - Typography

enum KitchenType {
    static let display = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let title   = Font.system(.title2,     design: .default).weight(.semibold)
    static let section = Font.headline
    static let body    = Font.subheadline
    static let detail  = Font.caption
    static let eyebrow = Font.caption2.weight(.semibold)
    static let metric  = Font.system(.title3, design: .rounded).weight(.bold).monospacedDigit()
}

// MARK: - Shadow

extension View {
    /// Unified soft neutral shadow for elevated surfaces.
    func kitchenShadow() -> some View {
        shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
    }
}

// MARK: - Button style

struct KitchenPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Card

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(KitchenTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                KitchenTheme.surfaceElevated,
                in: RoundedRectangle(cornerRadius: KitchenTheme.cardRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: KitchenTheme.cardRadius, style: .continuous)
                    .stroke(KitchenTheme.separator.opacity(0.5), lineWidth: 0.5)
            )
            .kitchenShadow()
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

