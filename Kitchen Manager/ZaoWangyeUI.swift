import SwiftUI

// MARK: - Card Shell
//
// HomePage's single hero moment. Cream-paper background with brandGold ring
// frames the artwork — no LinearGradients, no glow ellipses. The 灶王爷 portrait
// itself is the focal point; the container stays quiet.

struct ZaoWangyeCardShell<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var imageSize: CGFloat = 148
    let content: Content

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        imageSize: CGFloat = 148,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.imageSize = imageSize
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KitchenTheme.Spacing.lg) {
            HStack(alignment: .top, spacing: KitchenTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: KitchenTheme.Spacing.sm) {
                    Text(eyebrow)
                        .font(KitchenType.eyebrow)
                        .kerning(0.5)
                        .foregroundStyle(KitchenTheme.brandCrimson)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(KitchenTheme.brandCrimson.opacity(0.08), in: Capsule())

                    Text(title)
                        .font(KitchenType.title)
                        .foregroundStyle(KitchenTheme.textPrimary)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(KitchenType.body)
                            .foregroundStyle(KitchenTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
                ZaoWangyeArtwork(size: imageSize)
            }

            content
        }
        .padding(KitchenTheme.Spacing.lg + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            KitchenTheme.brandCream,
            in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTheme.Radius.xl, style: .continuous)
                .strokeBorder(KitchenTheme.brandGold.opacity(0.45), lineWidth: 1.2)
        )
        .kitchenShadow()
    }
}

// MARK: - Inset Panel

struct ZaoWangyeInsetPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KitchenTheme.Spacing.md) {
            content
        }
        .padding(KitchenTheme.Spacing.md + 2)
        .background(
            KitchenTheme.surfaceElevated,
            in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.lg, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTheme.Radius.lg, style: .continuous)
                .strokeBorder(KitchenTheme.separator.opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - Stat Pill

struct ZaoWangyeStatPill: View {
    let symbol: String
    let title: String
    let value: String
    var accent: Color = KitchenTheme.brandCrimson

    var body: some View {
        HStack(spacing: KitchenTheme.Spacing.sm + 2) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(KitchenTheme.textSecondary)
                Text(value)
                    .font(KitchenType.body.weight(.semibold))
                    .foregroundStyle(KitchenTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(KitchenTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            KitchenTheme.surfaceElevated,
            in: RoundedRectangle(cornerRadius: KitchenTheme.Radius.md + 2, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTheme.Radius.md + 2, style: .continuous)
                .strokeBorder(KitchenTheme.separator.opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - Surface Style (used by MealPlanPage AIChefModeSwitch)

struct ZaoWangyeSurfaceStyle: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: KitchenTheme.Radius.md + 2, style: .continuous)
                    .fill(selected ? KitchenTheme.brandCrimson.opacity(0.10) : KitchenTheme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: KitchenTheme.Radius.md + 2, style: .continuous)
                    .strokeBorder(
                        selected ? KitchenTheme.brandCrimson.opacity(0.40) : KitchenTheme.separator.opacity(0.5),
                        lineWidth: selected ? 1.2 : 0.5
                    )
            )
    }
}

extension View {
    func zaoWangyeSurface(selected: Bool = false) -> some View {
        modifier(ZaoWangyeSurfaceStyle(selected: selected))
    }
}

// MARK: - Brand Mark (Phase D commits this to all toolbars)

struct KitchenBrandMark: View {
    var size: CGFloat = 28

    var body: some View {
        Image("ZaoWangyeHero")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(KitchenTheme.brandGold.opacity(0.7), lineWidth: 1)
            )
    }
}

// MARK: - Artwork

private struct ZaoWangyeArtwork: View {
    let size: CGFloat

    var body: some View {
        Image("ZaoWangyeHero")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(KitchenTheme.brandGold.opacity(0.85), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
    }
}
