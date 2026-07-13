import SwiftUI

// MARK: - Color tokens

extension Color {
    // Maplog's original lime palette.
    static let maplogLime = Color(red: 0.76, green: 0.96, blue: 0.02)
    static let maplogLimePressed = Color(red: 0.64, green: 0.82, blue: 0.01)
    // Capture uses the same brand accent as the rest of Maplog.
    static let maplogCaptureAccent = maplogLime
    static let maplogInk = Color(red: 0.07, green: 0.08, blue: 0.08)
    static let maplogMuted = Color(red: 0.39, green: 0.41, blue: 0.42)
    static let maplogSubtle = Color(red: 0.53, green: 0.55, blue: 0.56)
    static let maplogLine = Color(red: 0.89, green: 0.90, blue: 0.89)
    static let maplogCanvas = Color(red: 0.965, green: 0.97, blue: 0.96)
    static let maplogSurface = Color.white
    static let maplogSurfaceRaised = Color(red: 0.985, green: 0.987, blue: 0.982)
    static let maplogOlive = Color(red: 0.32, green: 0.42, blue: 0.02)
    static let maplogDanger = Color(red: 0.75, green: 0.16, blue: 0.12)
    static let maplogOnPrimary = Color.white

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
    static let small: CGFloat = 6
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
    static let xLarge: CGFloat = 16
    static let hero: CGFloat = 24
}

enum MaplogSize {
    static let minimumTapTarget: CGFloat = 44
    static let compactControlHeight: CGFloat = 36
    static let controlHeight: CGFloat = 48
    static let primaryButtonHeight: CGFloat = 48
    static let searchHeight: CGFloat = 48
    static let chipHeight: CGFloat = 40
    static let listThumbnail: CGFloat = 82
    static let tabBarHeight: CGFloat = 66
    static let iconSmall: CGFloat = 16
    static let iconMedium: CGFloat = 20
    static let iconLarge: CGFloat = 24
}

// MARK: - Typography tokens

enum MaplogFont {
    static let largeTitle = Font.largeTitle.weight(.semibold)
    static let screenTitle = Font.title2.weight(.semibold)
    static let sectionTitle = Font.title3.weight(.semibold)
    static let cardTitle = Font.headline
    static let button = Font.headline
    static let body = Font.body
    static let bodyStrong = Font.body.weight(.semibold)
    static let callout = Font.callout
    static let calloutStrong = Font.callout.weight(.semibold)
    static let caption = Font.caption.weight(.medium)
    static let badge = Font.caption2.weight(.semibold)
    static let tabLabel = Font.caption2.weight(.semibold)
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
                        .stroke(Color.maplogBorder, lineWidth: 1)
                }
        case .elevated:
            background(Color.maplogSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.maplogBorder, lineWidth: 1)
                }
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
            .tint(Color.maplogPrimary)
    }
}
