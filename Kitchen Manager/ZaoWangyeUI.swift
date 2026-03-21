import SwiftUI

extension KitchenTheme {
    static let zaoCrimson = Color(red: 0.39, green: 0.11, blue: 0.08)
    static let zaoAmber = Color(red: 0.96, green: 0.48, blue: 0.08)
    static let zaoGold = Color(red: 0.99, green: 0.84, blue: 0.28)
    static let zaoSun = Color(red: 1.00, green: 0.68, blue: 0.18)
    static let zaoCream = Color(red: 1.00, green: 0.95, blue: 0.82)
    static let zaoMint = Color(red: 0.73, green: 0.98, blue: 0.54)
    static let zaoBlue = Color(red: 0.52, green: 0.82, blue: 1.00)
}

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
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            KitchenTheme.zaoCrimson,
                            Color(red: 0.61, green: 0.18, blue: 0.08),
                            KitchenTheme.zaoAmber
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ZaoWangyeBackdrop()
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            KitchenTheme.zaoGold.opacity(0.95),
                            .white.opacity(0.45),
                            KitchenTheme.zaoGold.opacity(0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.25
                )

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(eyebrow)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KitchenTheme.zaoCream.opacity(0.88))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.14), in: Capsule())

                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(KitchenTheme.zaoCream.opacity(0.95))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)

                    ZaoWangyeArtwork(size: imageSize)
                }

                HStack(spacing: 8) {
                    ZaoWangyeFeatureBadge(symbol: "fork.knife", title: "点菜")
                    ZaoWangyeFeatureBadge(symbol: "shippingbox.fill", title: "核库存")
                    ZaoWangyeFeatureBadge(symbol: "cart.badge.plus", title: "补待购")
                }

                content
            }
            .padding(20)
        }
        .shadow(color: KitchenTheme.zaoAmber.opacity(0.24), radius: 18, y: 10)
    }
}

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
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

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

struct ZaoWangyeFeatureBadge: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.caption2.weight(.semibold))
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 36)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.14), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

struct ZaoWangyeSurfaceStyle: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? .white.opacity(0.18) : .black.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        selected ? KitchenTheme.zaoGold.opacity(0.72) : .white.opacity(0.10),
                        lineWidth: selected ? 1.4 : 1
                    )
            )
    }
}

extension View {
    func zaoWangyeSurface(selected: Bool = false) -> some View {
        modifier(ZaoWangyeSurfaceStyle(selected: selected))
    }
}

private struct ZaoWangyeArtwork: View {
    let size: CGFloat

    var body: some View {
        Image("ZaoWangyeHero")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(.white.opacity(0.26), lineWidth: 1)
            )
            .shadow(color: KitchenTheme.zaoSun.opacity(0.40), radius: 22, y: 12)
    }
}

private struct ZaoWangyeBackdrop: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(KitchenTheme.zaoGold.opacity(0.56))
                .frame(width: 250, height: 250)
                .blur(radius: 34)
                .offset(x: -12, y: -76)

            Circle()
                .fill(KitchenTheme.zaoMint.opacity(0.24))
                .frame(width: 140, height: 140)
                .blur(radius: 22)
                .offset(x: 150, y: -80)

            Circle()
                .fill(KitchenTheme.zaoBlue.opacity(0.20))
                .frame(width: 150, height: 150)
                .blur(radius: 22)
                .offset(x: -160, y: 64)

            Circle()
                .fill(.white.opacity(0.11))
                .frame(width: 130, height: 130)
                .blur(radius: 16)
                .offset(x: 128, y: 88)
        }
    }
}
