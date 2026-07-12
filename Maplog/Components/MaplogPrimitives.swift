import SwiftUI

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
            .background(Color.maplogSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.maplogBorder.opacity(0.9), lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
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
            .foregroundStyle(isSelected ? Color.maplogInk : Color.maplogMuted)
            .padding(.horizontal, MaplogSpacing.medium)
            .frame(height: MaplogSize.chipHeight)
            .background(isSelected ? Color.maplogPrimary : Color.maplogSurface)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.maplogPrimary : Color.maplogBorder, lineWidth: 1)
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MaplogStatusBadge: View {
    let title: String
    var foreground = Color.maplogInk
    var background = Color.maplogLime

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
    var background = Color.maplogSurface.opacity(0.9)
    var foreground = Color.maplogInk
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(background)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct MaplogToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(MaplogFont.calloutStrong)
            .foregroundStyle(Color.maplogTextPrimary)
            .padding(.horizontal, MaplogSpacing.medium)
            .frame(minHeight: MaplogSize.controlHeight)
            .background(Color.maplogSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.maplogBorder.opacity(0.72), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)
            .accessibilityAddTraits(.isStaticText)
    }
}
