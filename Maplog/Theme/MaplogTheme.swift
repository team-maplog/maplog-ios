import SwiftUI

// MARK: - Color tokens

extension Color {
    // Primitive brand palette. The lime is Maplog's existing primary color.
    static let maplogLime = Color(red: 0.76, green: 0.96, blue: 0.02)
    static let maplogLimePressed = Color(red: 0.64, green: 0.82, blue: 0.01)
    static let maplogInk = Color(red: 0.07, green: 0.08, blue: 0.08)
    static let maplogMuted = Color(red: 0.39, green: 0.41, blue: 0.42)
    static let maplogSubtle = Color(red: 0.53, green: 0.55, blue: 0.56)
    static let maplogLine = Color(red: 0.89, green: 0.90, blue: 0.89)
    static let maplogCanvas = Color(red: 0.965, green: 0.97, blue: 0.96)
    static let maplogSurface = Color.white
    static let maplogSurfaceRaised = Color(red: 0.985, green: 0.987, blue: 0.982)
    static let maplogOlive = Color(red: 0.32, green: 0.42, blue: 0.02)
    static let maplogDanger = Color(red: 0.75, green: 0.16, blue: 0.12)

    // Semantic aliases used by components.
    static let maplogPrimary = maplogLime
    static let maplogPrimaryPressed = maplogLimePressed
    static let maplogTextPrimary = maplogInk
    static let maplogTextSecondary = maplogMuted
    static let maplogTextTertiary = maplogSubtle
    static let maplogBorder = maplogLine
    static let maplogBackground = maplogCanvas
}

// MARK: - Spacing and geometry tokens

enum MaplogSpacing {
    static let xxxSmall: CGFloat = 2
    static let xxSmall: CGFloat = 4
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 20
    static let xxLarge: CGFloat = 32
    static let xxxLarge: CGFloat = 40

    // Semantic layout spacing.
    static let page: CGFloat = large
    static let pageTop: CGFloat = medium
    static let section: CGFloat = xLarge
    static let stack: CGFloat = small
    static let inline: CGFloat = xSmall
    static let cardPadding: CGFloat = medium
    static let reelTopClearance: CGFloat = 64
    static let reelTabBarClearance: CGFloat = 112

    // Compatibility aliases. New code should use MaplogRadius.
    static let cardRadius: CGFloat = MaplogRadius.large
    static let controlRadius: CGFloat = MaplogRadius.medium
    static let smallRadius: CGFloat = MaplogRadius.small
}

enum MaplogRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 20
    static let xLarge: CGFloat = 24
    static let hero: CGFloat = 28
}

enum MaplogSize {
    static let minimumTapTarget: CGFloat = 44
    static let compactControlHeight: CGFloat = 36
    static let controlHeight: CGFloat = 48
    static let primaryButtonHeight: CGFloat = 52
    static let searchHeight: CGFloat = 50
    static let chipHeight: CGFloat = 40
    static let listThumbnail: CGFloat = 82
    static let tabBarHeight: CGFloat = 66
    static let iconSmall: CGFloat = 16
    static let iconMedium: CGFloat = 20
    static let iconLarge: CGFloat = 24
}

// MARK: - Typography tokens

enum MaplogFont {
    static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let screenTitle = Font.system(size: 22, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let cardTitle = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let button = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 15, weight: .regular, design: .rounded)
    static let bodyStrong = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let callout = Font.system(size: 14, weight: .regular, design: .rounded)
    static let calloutStrong = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let badge = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let tabLabel = Font.system(size: 11, weight: .semibold, design: .rounded)
}

enum MaplogCardStyle {
    case standard
    case elevated
    case photo
}

// MARK: - Shared surface modifiers

extension View {
    @ViewBuilder
    func maplogCard(
        cornerRadius: CGFloat = MaplogRadius.large,
        style: MaplogCardStyle = .standard
    ) -> some View {
        switch style {
        case .standard:
            background(Color.maplogSurface)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.maplogBorder.opacity(0.82), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.025), radius: 1, x: 0, y: 0)
                .shadow(color: .black.opacity(0.045), radius: 6, x: 0, y: 2)
        case .elevated:
            background(Color.maplogSurface)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.maplogBorder.opacity(0.68), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.035), radius: 3, x: 0, y: 1)
                .shadow(color: .black.opacity(0.09), radius: 12, x: 0, y: 5)
        case .photo:
            background(Color.maplogSurface)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    func maplogPagePadding() -> some View {
        padding(.horizontal, MaplogSpacing.page)
    }

    func maplogListBottomPadding() -> some View {
        padding(.bottom, MaplogSpacing.section)
    }

    func maplogScreenSurface() -> some View {
        background(Color.maplogBackground.ignoresSafeArea())
    }

    func maplogNavigationAppearance() -> some View {
        toolbarBackground(Color.maplogSurface, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .tint(Color.maplogTextPrimary)
    }
}
