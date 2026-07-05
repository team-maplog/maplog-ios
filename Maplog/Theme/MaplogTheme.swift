import SwiftUI

extension Color {
    static let maplogLime = Color(red: 0.76, green: 0.96, blue: 0.02)
    static let maplogInk = Color(red: 0.06, green: 0.07, blue: 0.07)
    static let maplogMuted = Color(red: 0.45, green: 0.47, blue: 0.48)
    static let maplogLine = Color(red: 0.90, green: 0.91, blue: 0.91)
    static let maplogCanvas = Color(red: 0.96, green: 0.97, blue: 0.96)
    static let maplogOlive = Color(red: 0.32, green: 0.42, blue: 0.02)
}

enum MaplogSpacing {
    static let page: CGFloat = 20
    static let pageTop: CGFloat = 18
    static let section: CGFloat = 24
    static let stack: CGFloat = 14
    static let inline: CGFloat = 8
    static let cardPadding: CGFloat = 16
    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 14
    static let smallRadius: CGFloat = 8
}

enum MaplogSize {
    static let minimumTapTarget: CGFloat = 44
    static let primaryButtonHeight: CGFloat = 52
    static let searchHeight: CGFloat = 50
    static let chipHeight: CGFloat = 42
    static let listThumbnail: CGFloat = 82
    static let tabBarHeight: CGFloat = 66
}

enum MaplogFont {
    static let largeTitle = Font.system(size: 28, weight: .black)
    static let screenTitle = Font.system(size: 22, weight: .bold)
    static let sectionTitle = Font.system(size: 20, weight: .bold)
    static let cardTitle = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 14, weight: .medium)
    static let callout = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 12, weight: .semibold)
    static let tabLabel = Font.system(size: 11, weight: .semibold)
}

extension View {
    func maplogCard(cornerRadius: CGFloat = MaplogSpacing.cardRadius) -> some View {
        background(.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.maplogLine.opacity(0.78), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.035), radius: 14, x: 0, y: 6)
    }

    func maplogPagePadding() -> some View {
        padding(.horizontal, MaplogSpacing.page)
    }

    func maplogListBottomPadding() -> some View {
        padding(.bottom, MaplogSpacing.section)
    }
}
