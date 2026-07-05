import SwiftUI

struct TripCardView: View {
    let trip: MaplogTrip
    var isLarge = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TravelImageView(style: trip.coverStyle, height: isLarge ? 180 : 136)
                .overlay(alignment: .topLeading) {
                    MaplogStatusBadge(title: trip.duration)
                        .padding(10)
                }

            VStack(alignment: .leading, spacing: 5) {
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
        .maplogCard()
    }
}

struct SavedRouteActionCard: View {
    let trip: MaplogTrip
    var statusText = "저장됨"
    var note = "언제든 다시 따라갈 수 있어요"
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                RouteDetailView(trip: trip)
            } label: {
                TripCardView(trip: trip, isLarge: true)
                    .overlay(alignment: .topTrailing) {
                        Text(statusText)
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(Color.maplogLime)
                            .clipShape(Capsule())
                            .padding(12)
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
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(trip.title) 지도에서 보기")

                Button(action: onRemove) {
                    Label("저장 해제", systemImage: "bookmark.slash")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Color.maplogCanvas)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(trip.title) 저장 해제")
            }
            .font(.system(size: 12, weight: .bold))
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 42, height: 42)
                    .background(Color.maplogLime)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            NavigationLink {
                destination()
            } label: {
                Label(buttonTitle, systemImage: "tray.full.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.maplogCanvas)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(MaplogSpacing.cardPadding)
        .maplogCard()
    }
}

struct SpotRowCard: View {
    let spot: MaplogSpot

    var body: some View {
        HStack(spacing: 12) {
            TravelImageView(style: spot.imageStyle, height: MaplogSize.listThumbnail, cornerRadius: MaplogSpacing.smallRadius)
                .frame(width: MaplogSize.listThumbnail)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(spot.category)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                    Spacer()
                    Label(String(format: "%.1f", spot.rating), systemImage: "star.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                }
                Text(spot.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                Text(spot.area)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
            }
        }
        .padding(10)
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
