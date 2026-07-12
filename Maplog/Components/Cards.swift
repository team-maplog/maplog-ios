import SwiftUI

struct TripCardView: View {
    let trip: MaplogTrip
    var isLarge = false

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            TravelImageView(style: trip.coverStyle, height: isLarge ? 180 : 136)
                .overlay(alignment: .topLeading) {
                    MaplogStatusBadge(title: trip.duration)
                        .padding(MaplogSpacing.xSmall)
                }

            VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                Text(trip.title)
                    .font(isLarge ? MaplogFont.screenTitle : MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogInk)
                Text(trip.subtitle)
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                    Text("\(trip.location) · \(trip.spots.count)개 장소")
                }
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogMuted)
            }
            .padding(.horizontal, MaplogSpacing.stack)
            .padding(.bottom, MaplogSpacing.stack)
        }
        .frame(width: isLarge ? nil : 236)
        .maplogCard(style: .photo)
    }
}

struct SavedRouteActionCard: View {
    let trip: MaplogTrip
    var statusText = "저장됨"
    var note = "언제든 다시 따라갈 수 있어요"
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            NavigationLink {
                RouteDetailView(trip: trip)
            } label: {
                TripCardView(trip: trip, isLarge: true)
                    .overlay(alignment: .topTrailing) {
                        Text(statusText)
                            .font(MaplogFont.badge)
                            .foregroundStyle(Color.maplogInk)
                            .padding(.horizontal, MaplogSpacing.small)
                            .frame(height: 28)
                            .background(Color.maplogLime)
                            .clipShape(Capsule())
                            .padding(MaplogSpacing.small)
                    }
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Label(note, systemImage: "bookmark.fill")
                    .lineLimit(1)

                Spacer(minLength: 8)

                NavigationLink {
                    MapSearchView(query: trip.location)
                } label: {
                    Label("지도 보기", systemImage: "map.fill")
                        .font(MaplogFont.caption)
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, MaplogSpacing.small)
                        .frame(height: 34)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(trip.title) 지도에서 보기")

                Button(action: onRemove) {
                    Label("저장 해제", systemImage: "bookmark.slash")
                        .font(MaplogFont.caption)
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, MaplogSpacing.small)
                        .frame(height: 34)
                        .background(Color.maplogCanvas)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(trip.title) 저장 해제")
            }
            .font(MaplogFont.caption)
            .foregroundStyle(Color.maplogMuted)
            .padding(.horizontal, 2)
        }
    }
}

struct SavedConfirmationCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let systemImage: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.stack) {
            HStack(spacing: MaplogSpacing.small) {
                Image(systemName: systemImage)
                    .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 42, height: 42)
                    .background(Color.maplogLime)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                    Text(title)
                        .font(MaplogFont.cardTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text(subtitle)
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            NavigationLink {
                destination()
            } label: {
                Label(buttonTitle, systemImage: "tray.full.fill")
                    .font(MaplogFont.bodyStrong)
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: MaplogSize.controlHeight)
                    .background(Color.maplogCanvas)
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(MaplogSpacing.cardPadding)
        .maplogCard(style: .elevated)
    }
}

struct SpotRowCard: View {
    let spot: MaplogSpot

    var body: some View {
        HStack(spacing: MaplogSpacing.small) {
            TravelImageView(style: spot.imageStyle, height: MaplogSize.listThumbnail, cornerRadius: MaplogSpacing.smallRadius)
                .frame(width: MaplogSize.listThumbnail)

            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                HStack {
                    Text(spot.category)
                        .font(MaplogFont.badge)
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, MaplogSpacing.xSmall)
                        .padding(.vertical, MaplogSpacing.xxSmall)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                    Spacer()
                    Label(String(format: "%.1f", spot.rating), systemImage: "star.fill")
                        .font(MaplogFont.caption)
                        .foregroundStyle(Color.maplogInk)
                }
                Text(spot.name)
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogInk)
                Text(spot.area)
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogMuted)
            }
        }
        .padding(MaplogSpacing.xSmall)
        .maplogCard()
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        MaplogSectionHeader(title, subtitle: subtitle)
    }
}
