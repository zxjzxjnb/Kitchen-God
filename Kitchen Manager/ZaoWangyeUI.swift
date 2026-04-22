import SwiftUI

extension KitchenTheme {
    static let zaoCrimson = Color(red: 0.39, green: 0.11, blue: 0.08)
    static let zaoAmber   = Color(red: 0.96, green: 0.48, blue: 0.08)
    static let zaoGold    = Color(red: 0.99, green: 0.84, blue: 0.28)
    static let zaoSun     = Color(red: 1.00, green: 0.68, blue: 0.18)
    static let zaoCream   = Color(red: 1.00, green: 0.95, blue: 0.82)
    static let zaoMint    = Color(red: 0.73, green: 0.98, blue: 0.54)
    static let zaoBlue    = Color(red: 0.52, green: 0.82, blue: 1.00)
}

// MARK: - Card Shell

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
        ZStack(alignment: .topLeading) {
            // Background — deep crimson to glowing amber
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.33, green: 0.07, blue: 0.03), location: 0.0),
                        .init(color: Color(red: 0.58, green: 0.13, blue: 0.04), location: 0.55),
                        .init(color: Color(red: 0.88, green: 0.36, blue: 0.04), location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            // Atmosphere
            ZaoWangyeBackdrop()
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            // Gold shimmer border
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: KitchenTheme.zaoGold.opacity(0.95), location: 0.0),
                            .init(color: .white.opacity(0.45), location: 0.30),
                            .init(color: KitchenTheme.zaoGold.opacity(0.20), location: 1.0),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(eyebrow)
                            .font(.caption2.weight(.semibold))
                            .kerning(0.5)
                            .foregroundStyle(KitchenTheme.zaoCream.opacity(0.78))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.22), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.8))

                        Text(title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)

                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(KitchenTheme.zaoCream.opacity(0.90))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)
                    ZaoWangyeArtwork(size: imageSize)
                }

                content
            }
            .padding(20)
        }
        .shadow(
            color: Color(red: 0.50, green: 0.10, blue: 0.03).opacity(0.60),
            radius: 24, y: 14
        )
    }
}

// MARK: - Inset Panel

struct ZaoWangyeInsetPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Stat Pill

struct ZaoWangyeStatPill: View {
    let symbol: String
    let title: String
    let value: String
    var accent: Color = KitchenTheme.zaoGold

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(.black.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(KitchenTheme.zaoCream.opacity(0.86))
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Surface Style

struct ZaoWangyeSurfaceStyle: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? .white.opacity(0.16) : .black.opacity(0.20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        selected ? KitchenTheme.zaoGold.opacity(0.82) : .white.opacity(0.09),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
    }
}

extension View {
    func zaoWangyeSurface(selected: Bool = false) -> some View {
        modifier(ZaoWangyeSurfaceStyle(selected: selected))
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
                    .strokeBorder(
                        LinearGradient(
                            colors: [KitchenTheme.zaoGold.opacity(0.90), .white.opacity(0.22)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.8
                    )
            )
            .shadow(color: KitchenTheme.zaoSun.opacity(0.60), radius: 16, y: 8)
    }
}

// MARK: - Backdrop

private struct ZaoWangyeBackdrop: View {
    var body: some View {
        ZStack {
            // Warm glow anchored at top-center — lights up the title area
            Ellipse()
                .fill(KitchenTheme.zaoGold.opacity(0.40))
                .frame(width: 200, height: 140)
                .blur(radius: 36)
                .offset(x: -20, y: -50)

            // Hot accent behind the artwork circle
            Circle()
                .fill(KitchenTheme.zaoSun.opacity(0.45))
                .frame(width: 100)
                .blur(radius: 24)
                .offset(x: 110, y: -36)

            // Subtle bottom warmth
            Circle()
                .fill(KitchenTheme.zaoAmber.opacity(0.18))
                .frame(width: 180)
                .blur(radius: 32)
                .offset(x: 30, y: 100)
        }
    }
}
