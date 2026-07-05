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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 19, weight: .bold))
                    }

                    Text(title)
                }
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogInk)

                if let subtitle {
                    Text(subtitle)
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogMuted)
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
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                Text(placeholder)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.maplogMuted.opacity(0.82))
            .padding(.horizontal, 16)
            .frame(height: MaplogSize.searchHeight)
            .background(.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.maplogLine.opacity(0.62), lineWidth: 1))
            .shadow(color: .black.opacity(0.035), radius: 12, x: 0, y: 6)
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
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isSelected ? Color.maplogInk : Color.maplogMuted)
            .padding(.horizontal, 18)
            .frame(height: MaplogSize.chipHeight)
            .background(isSelected ? Color.maplogLime : .white)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.maplogLime : Color.maplogMuted.opacity(0.32), lineWidth: 1)
            }
            .shadow(color: isSelected ? Color.maplogLime.opacity(0.22) : .clear, radius: 10, x: 0, y: 4)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MaplogStatusBadge: View {
    let title: String
    var foreground = Color.maplogInk
    var background = Color.maplogLime

    var body: some View {
        Text(title)
            .font(MaplogFont.caption.weight(.black))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .frame(minHeight: 24)
            .background(background)
            .clipShape(Capsule())
    }
}

struct MaplogIconButton: View {
    let systemName: String
    var accessibilityLabel: String
    var size: CGFloat = MaplogSize.minimumTapTarget
    var background = Color.white.opacity(0.82)
    var foreground = Color.maplogInk
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(background)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
