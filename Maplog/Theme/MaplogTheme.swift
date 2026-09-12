import SwiftUI

// MARK: - Color tokens

extension Color {
    // Asset-backed semantic colors keep every feature on the same visual system.
    // 기존 호출부와의 호환성을 위해 이름은 유지합니다.
    // 에셋은 Maplog의 라임 팔레트 브랜드 포인트 색입니다.
    static let maplogLime = Color("MaplogAccent")
    static let maplogLimePressed = Color("MaplogAccentPressed")
    static let maplogCaptureAccent = maplogLime
    static let maplogInk = Color("MaplogInk")
    static let maplogMuted = Color("MaplogMuted")
    static let maplogSubtle = Color("MaplogSubtle")
    static let maplogLine = Color("MaplogLine")
    static let maplogCanvas = Color("MaplogCanvas")
    static let maplogSurface = Color("MaplogSurface")
    static let maplogSurfaceRaised = Color("MaplogSurfaceRaised")
    static let maplogOlive = Color("MaplogOlive")
    static let maplogDanger = Color("MaplogDanger")
    static let maplogOnPrimary = Color("MaplogOnAccent")

    // Semantic aliases used by components.
    static let maplogPrimary = maplogLime
    static let maplogPrimaryPressed = maplogLimePressed
    static let maplogTextPrimary = maplogInk
    static let maplogTextSecondary = maplogMuted
    static let maplogTextTertiary = maplogSubtle
    static let maplogBorder = maplogLine
    static let maplogBackground = maplogCanvas

    // 지도 타일 위 정보는 기기 색상 모드와 무관하게 라이트 톤을 유지함.
    // 도로·지명과 겹쳐도 카드와 텍스트 대비를 일정하게 만드는 전용 토큰임.
    static let maplogMapLightCanvas = Color(
        red: 0.965,
        green: 0.970,
        blue: 0.960
    )
    static let maplogMapLightSurface = Color.white
    static let maplogMapLightSurfaceRaised = Color(
        red: 0.985,
        green: 0.987,
        blue: 0.982
    )
    static let maplogMapLightTextPrimary = Color(
        red: 0.070,
        green: 0.080,
        blue: 0.080
    )
    static let maplogMapLightTextSecondary = Color(
        red: 0.390,
        green: 0.410,
        blue: 0.420
    )
    static let maplogMapLightBorder = Color(
        red: 0.890,
        green: 0.900,
        blue: 0.890
    )
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

// MARK: - Symbol tokens

enum MaplogSymbol {
    /// A single, familiar SF Symbol for every action that opens turn-by-turn directions.
    static let directions = "location.north.line.fill"
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
                .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 4)
        case .elevated:
            background(Color.maplogSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.055), radius: 16, x: 0, y: 7)
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
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(Color.maplogInk)
    }
}
