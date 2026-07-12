import SwiftUI

struct TravelImageView: View {
    let style: PhotoStyle
    var height: CGFloat
    var cornerRadius: CGFloat = MaplogSpacing.cardRadius
    var showsSymbol = true

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(style.assetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )

            if showsSymbol {
                Image(systemName: style.symbol)
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(18)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var colors: [Color] {
        switch style {
        case .mountain:
            return [Color(red: 0.24, green: 0.35, blue: 0.31), Color(red: 0.71, green: 0.84, blue: 0.66)]
        case .ocean:
            return [Color(red: 0.06, green: 0.38, blue: 0.62), Color(red: 0.63, green: 0.86, blue: 0.91)]
        case .city:
            return [Color(red: 0.08, green: 0.10, blue: 0.13), Color(red: 0.67, green: 0.72, blue: 0.72)]
        case .night:
            return [Color(red: 0.05, green: 0.06, blue: 0.12), Color(red: 0.27, green: 0.32, blue: 0.55)]
        case .cafe:
            return [Color(red: 0.34, green: 0.25, blue: 0.18), Color(red: 0.83, green: 0.74, blue: 0.60)]
        case .forest:
            return [Color(red: 0.12, green: 0.40, blue: 0.27), Color(red: 0.70, green: 0.86, blue: 0.49)]
        case .temple:
            return [Color(red: 0.46, green: 0.20, blue: 0.18), Color(red: 0.88, green: 0.74, blue: 0.47)]
        case .market:
            return [Color(red: 0.66, green: 0.23, blue: 0.20), Color(red: 0.95, green: 0.73, blue: 0.35)]
        case .festival:
            return [Color(red: 0.96, green: 0.52, blue: 0.62), Color(red: 0.30, green: 0.62, blue: 0.92)]
        case .palace:
            return [Color(red: 0.16, green: 0.24, blue: 0.20), Color(red: 0.76, green: 0.55, blue: 0.31)]
        case .alley:
            return [Color(red: 0.44, green: 0.31, blue: 0.20), Color(red: 0.78, green: 0.67, blue: 0.50)]
        }
    }
}

/// 지도 장소 데이터에 연결된 사진을 동일한 크롭 규칙으로 보여줍니다.
/// 지도 핀처럼 작은 원형 썸네일에서도 사진 밖의 UI가 보이지 않도록 항상 잘라냅니다.
struct MaplogSpotImageView: View {
    let spot: MaplogSpot
    var height: CGFloat
    var cornerRadius: CGFloat = MaplogSpacing.cardRadius

    private var assetName: String {
        spot.imageAssetName ?? spot.imageStyle.assetName
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct VlogPostImageView: View {
    let post: VlogPost
    var cornerRadius: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var assetName: String {
        switch post.id {
        case "post-1":
            return "log_seongsu_evening"
        case "post-2":
            return "log_jeju_sunrise"
        case "search-busan-night-route":
            return "log_busan_night"
        default:
            switch post.imageStyle {
            case .city, .cafe, .alley:
                return "log_seongsu_evening"
            case .forest, .mountain, .palace:
                return "log_jeju_sunrise"
            case .night, .ocean, .market, .festival, .temple:
                return "log_busan_night"
            }
        }
    }
}

/// 영상 한 편에 포함된 장소들을 실제 지도 연결 전 목업 경로로 보여주는 릴스용 페이지입니다.
struct MaplogReelRoutePage: View {
    let post: VlogPost
    let trip: MaplogTrip
    @State private var selectedSpotID: String?

    private let routeCardHeight: CGFloat = 190
    private let routeCardBottomClearance: CGFloat = MaplogSpacing.reelTabBarClearance + 20

    init(post: VlogPost, trip: MaplogTrip) {
        self.post = post
        self.trip = trip
        _selectedSpotID = State(initialValue: trip.spots.first?.id)
    }

    private var nearbyRecommendations: [MaplogSpot] {
        trip.nearbySpots
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                RouteDetailHeroMap(
                    spots: trip.spots,
                    nearbySpots: nearbyRecommendations,
                    height: proxy.size.height,
                    selectedSpotID: selectedSpotID
                )

                LinearGradient(
                    colors: [.clear, .black.opacity(0.06), .black.opacity(0.66)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: MaplogSpacing.small) {
                    Spacer(minLength: 0)

                    nearbyRecommendationSummary

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .bottom, spacing: MaplogSpacing.small) {
                            ForEach(Array(trip.spots.enumerated()), id: \.element.id) { index, spot in
                                routeStopCard(spot: spot, index: index)
                                    .frame(width: min(max(proxy.size.width - 94, 252), 330))
                                    .frame(height: routeCardHeight, alignment: .bottom)
                                    .id(spot.id)
                                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                        content
                                            .opacity(phase.isIdentity ? 1 : 0.76)
                                            .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                    }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .frame(height: routeCardHeight)
                    .contentMargins(.horizontal, MaplogSpacing.page, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .scrollPosition(id: $selectedSpotID, anchor: .center)
                }
                .padding(.bottom, proxy.safeAreaInsets.bottom + routeCardBottomClearance)
            }
        }
        .background(Color(red: 0.90, green: 0.94, blue: 0.90))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(post.title)의 3km 주변 추천 지도")
    }

    private var nearbyRecommendationSummary: some View {
        HStack(spacing: MaplogSpacing.xSmall) {
            Image(systemName: "play.fill")
                .foregroundStyle(Color.maplogInk)
            Text("내 기록")
                .font(.caption.weight(.bold))
            Divider()
                .frame(height: 12)
            Image(systemName: "sparkles")
                .foregroundStyle(Color.maplogOlive)
            Text("3km 이내 추천")
                .font(.caption.weight(.bold))
            Spacer(minLength: 0)
            Text("\(nearbyRecommendations.count)곳")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.maplogOlive)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, MaplogSpacing.page)
        .accessibilityElement(children: .combine)
    }

    private func routeStopCard(spot: MaplogSpot, index: Int) -> some View {
        let isSelected = selectedSpotID == spot.id

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: MaplogSpacing.small) {
                MaplogSpotImageView(spot: spot, height: 54, cornerRadius: 14)
                    .frame(width: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(index + 1)번째 장소")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.maplogOlive)
                    Text(spot.name)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Text(spot.area)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text("\(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 30, height: 30)
                    .background(Color.maplogLime, in: Circle())
            }

            Text(spot.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: MaplogSpacing.xSmall) {
                NavigationLink {
                    SpotDetailView(spot: spot)
                } label: {
                    Label("장소 보기", systemImage: "mappin.and.ellipse")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 40)
                        .background(.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                }
                .buttonStyle(.plain)

                NavigationLink {
                    PopularMaplogDetailView(post: post, trip: trip)
                } label: {
                    Label("전체 루트", systemImage: "location.north.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 40)
                        .background(Color.maplogLime)
                        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.primary)
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.xLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MaplogRadius.xLarge, style: .continuous)
                .stroke(isSelected ? Color.maplogLime : Color.white.opacity(0.16), lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(index + 1)번째 장소, \(spot.name), \(spot.area)")
    }
}

/// 릴스와 전체 루트 페이지를 구분하는 최소한의 아이콘형 표시입니다.
struct MaplogReelPageCue: View {
    let selectedPage: Int

    var body: some View {
        HStack(spacing: MaplogSpacing.xSmall) {
            pageIndicator(systemImage: "play.rectangle.fill", isSelected: selectedPage == 0)
            pageIndicator(systemImage: "map.fill", isSelected: selectedPage == 1)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selectedPage == 0 ? "릴스 페이지, 왼쪽으로 밀면 전체 루트를 볼 수 있습니다" : "전체 루트 페이지, 오른쪽으로 밀면 릴스로 돌아갑니다")
    }

    private func pageIndicator(systemImage: String, isSelected: Bool) -> some View {
        Image(systemName: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(isSelected ? Color.maplogInk : .white)
            .frame(width: 42, height: 30)
            .background(isSelected ? Color.maplogLime : Color.black.opacity(0.42), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(isSelected ? 0 : 0.2), lineWidth: 1)
            }
    }
}

struct TravelLogImageView: View {
    let log: TravelLog
    var cornerRadius: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var assetName: String {
        switch log.id {
        case "log-1":
            return "log_busan_night"
        case "log-2":
            return "log_seongsu_evening"
        case "log-3":
            return "log_jeju_sunrise"
        default:
            switch log.imageStyle {
            case .city, .cafe, .alley:
                return "log_seongsu_evening"
            case .forest, .mountain, .palace:
                return "log_jeju_sunrise"
            case .night, .ocean, .market, .festival, .temple:
                return "log_busan_night"
            }
        }
    }
}

/// 촬영 플로우에서 사용하는 글자 없는 여행 목업 이미지입니다.
/// 실제 사진 데이터가 연결되기 전까지 썸네일과 미리보기의 비율을 일정하게 유지합니다.
struct CaptureTravelImageView: View {
    let style: PhotoStyle
    var cornerRadius: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityLabel("여행 사진 미리보기")
    }

    private var assetName: String {
        switch style {
        case .cafe:
            return "photo_cafe"
        case .city, .alley:
            return "log_seongsu_evening"
        case .forest, .mountain:
            return "log_jeju_sunrise"
        case .night, .ocean:
            return "log_busan_night"
        case .palace, .temple:
            return "home_gwanghwamun_photo"
        case .festival, .market:
            return "event_ocean_film_hero"
        }
    }
}
