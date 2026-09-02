import SwiftUI

/// 사용자 제공 지도 글리프를 앱 전반에서 같은 비율로 사용한다.
struct MaplogMapGlyphIcon: View {
    var size: CGFloat = MaplogSize.iconMedium

    var body: some View {
        Image("MaplogMapGlyph")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// 사용자 제공 위치 핀 글리프를 주소 메타데이터에 사용한다.
struct MaplogPinGlyphIcon: View {
    var size: CGFloat = MaplogSize.iconSmall

    var body: some View {
        Image("MaplogPinGlyph")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// 원형 SF Symbol 대신 프로젝트의 위치 핀 글리프와 문구를 함께 표시한다.
/// 위치를 뜻하는 보조 문구에서 같은 아이콘 비율을 유지하는 용도다.
struct MaplogLocationLabel: View {
    let title: String
    var pinSize: CGFloat = MaplogSize.iconSmall

    var body: some View {
        HStack(spacing: MaplogSpacing.xxxSmall) {
            MaplogPinGlyphIcon(size: pinSize)
            Text(title)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MaplogSectionHeader<Action: View>: View {
    let title: String
    var systemImage: String?
    var subtitle: String?
    @ViewBuilder let action: () -> Action

    init(
        _ title: String,
        systemImage: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder action: @escaping () -> Action
    ) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MaplogSpacing.medium) {
            VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                HStack(spacing: MaplogSpacing.xSmall) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                    }

                    Text(title)
                }
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogInk)

                if let subtitle {
                    Text(subtitle)
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: MaplogSpacing.inline)

            action()
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogMuted)
        }
    }
}

extension MaplogSectionHeader where Action == EmptyView {
    init(
        _ title: String,
        systemImage: String? = nil,
        subtitle: String? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.action = { EmptyView() }
    }
}

struct MaplogSearchButton<Destination: View>: View {
    let placeholder: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: MaplogSpacing.small) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                Text(placeholder)
                    .font(MaplogFont.body)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.maplogMuted.opacity(0.82))
            .padding(.horizontal, MaplogSpacing.medium)
            .frame(height: MaplogSize.searchHeight)
            .background(Color.maplogCanvas, in: RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(placeholder) 검색")
    }
}

struct MaplogFilterChip: View {
    let title: String
    var isSelected = false

    var body: some View {
        Text(title)
            .font(MaplogFont.calloutStrong)
            .foregroundStyle(isSelected ? Color.maplogOnPrimary : Color.maplogMuted)
            .padding(.horizontal, MaplogSpacing.medium)
            .frame(height: MaplogSize.chipHeight)
            .background(isSelected ? Color.maplogPrimary : .clear, in: RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MaplogStatusBadge: View {
    let title: String
    var foreground = Color.maplogOnPrimary
    var background = Color.maplogPrimary

    var body: some View {
        Text(title)
            .font(MaplogFont.badge)
            .foregroundStyle(foreground)
            .padding(.horizontal, MaplogSpacing.small)
            .frame(minHeight: 24)
            .background(background)
            .clipShape(Capsule())
    }
}

struct MaplogIconButton: View {
    let systemName: String
    var accessibilityLabel: String
    var size: CGFloat = MaplogSize.minimumTapTarget
    var foreground = Color.maplogInk
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Shared, unframed navigation action. The 44pt hit target stays intact while
/// the visual remains as quiet as the rest of the interface.
struct MaplogNavigationButton: View {
    let systemName: String
    let accessibilityLabel: String
    var foreground = Color.maplogInk
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(MaplogPressFeedbackStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Use over photography and video where contrast is needed without adding a
/// decorative circular container.
struct MaplogOverlayIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.46), radius: 3, x: 0, y: 1)
                .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(MaplogPressFeedbackStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

struct MaplogToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(MaplogFont.calloutStrong)
            .foregroundStyle(Color.maplogInk)
            .padding(.horizontal, MaplogSpacing.medium)
            .frame(minHeight: MaplogSize.controlHeight)
            .background(Color.maplogSurfaceRaised)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
            .accessibilityAddTraits(.isStaticText)
    }
}
