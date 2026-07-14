import Foundation

enum MockMaplogData {
    static let spotlightEvent = FeaturedEvent(
        id: "event-seoul-light-gwanghwamun",
        title: "서울라이트 광화문 빛의 향연",
        period: "2026. 6. 19. ~ 2026. 6. 22.",
        location: "서울",
        imageStyle: .palace,
        heroAssetName: "event_seoul_light_gwanghwamun_hero"
    )

    static let seoulTower = MaplogSpot(
        id: "spot-seoul-tower",
        name: "서울라이트 광화문",
        category: "야경",
        area: "서울 종로구",
        summary: "도심 속에서 펼쳐지는 화려한 미디어 아트. 오늘 밤 광화문 광장에서 특별한 추억을 만들기 좋은 장소.",
        rating: 4.7,
        imageStyle: .night,
        imageAssetName: "home_gwanghwamun_photo",
        tags: ["광화문", "야경", "미디어아트"],
        pinX: 0.48,
        pinY: 0.34
    )

    static let forestCafe = MaplogSpot(
        id: "spot-forest-cafe",
        name: "오우드 성수",
        category: "카페",
        area: "서울 성동구",
        summary: "성수동 힙플 투어 중 쉬어가기 좋은 카페. 비밀스러운 골목 분위기와 부드러운 커피가 어울린다.",
        rating: 4.5,
        imageStyle: .cafe,
        imageAssetName: "photo_cafe",
        tags: ["커피", "산책", "휴식"],
        pinX: 0.32,
        pinY: 0.58
    )

    static let jejuOreum = MaplogSpot(
        id: "spot-jeju-oreum",
        name: "새별오름",
        category: "자연",
        area: "제주 제주시 애월읍",
        summary: "억새 능선을 따라 일몰을 보기 좋은 제주 서쪽 오름. 정상까지 천천히 걸어도 한 시간이면 충분해요.",
        rating: 4.9,
        imageStyle: .forest,
        imageAssetName: "log_jeju_sunrise",
        tags: ["제주", "오름", "일몰", "억새"],
        pinX: 0.70,
        pinY: 0.46
    )

    static let aewolCoast = MaplogSpot(
        id: "spot-aewol-coast",
        name: "한담해안산책로",
        category: "산책",
        area: "제주 제주시 애월읍",
        summary: "바다 바로 옆으로 이어지는 완만한 산책로. 새별오름 전후로 천천히 걷기 좋아요.",
        rating: 4.7,
        imageStyle: .ocean,
        imageAssetName: "event_ocean_film_hero",
        tags: ["애월", "해안산책", "제주바다"],
        pinX: 0.58,
        pinY: 0.60
    )

    static let seongsuAlley = MaplogSpot(
        id: "spot-seongsu-alley",
        name: "연무장길",
        category: "골목",
        area: "서울 성동구 성수동",
        summary: "오래된 공장과 작은 편집숍, 카페가 자연스럽게 이어지는 성수동 산책길.",
        rating: 4.6,
        imageStyle: .city,
        imageAssetName: "log_seongsu_evening",
        tags: ["성수", "골목", "카페", "산책"],
        pinX: 0.38,
        pinY: 0.54
    )

    static let seoulForest = MaplogSpot(
        id: "spot-seoul-forest",
        name: "서울숲",
        category: "공원",
        area: "서울 성동구 성수동",
        summary: "성수 골목에서 잠시 벗어나 나무 그늘과 잔디 사이를 천천히 걷기 좋은 도심 공원.",
        rating: 4.8,
        imageStyle: .forest,
        imageAssetName: "log_jeju_sunrise",
        tags: ["서울숲", "산책", "피크닉", "성수"],
        pinX: 0.69,
        pinY: 0.30
    )

    static let ttukseomRiverPark = MaplogSpot(
        id: "spot-ttukseom-river-park",
        name: "뚝섬한강공원",
        category: "한강",
        area: "서울 광진구 자양동",
        summary: "성수에서 한강 쪽으로 이어 걸으며 노을과 강변 풍경으로 하루를 마무리하기 좋은 장소.",
        rating: 4.7,
        imageStyle: .ocean,
        imageAssetName: "event_ocean_film_hero",
        tags: ["한강", "노을", "산책", "서울"],
        pinX: 0.76,
        pinY: 0.72
    )

    static let busanMarket = MaplogSpot(
        id: "spot-busan-market",
        name: "북촌 한옥마을",
        category: "문화",
        area: "서울 종로구",
        summary: "경복궁 경로 주변에서 함께 둘러보기 좋은 한옥 골목.",
        rating: 4.6,
        imageStyle: .alley,
        imageAssetName: "photo_alley",
        tags: ["한옥", "산책", "사진"],
        pinX: 0.61,
        pinY: 0.70
    )

    static let gwanganBridgeNight = MaplogSpot(
        id: "spot-gwangan-night",
        name: "광안대교 야경 포인트",
        category: "야경",
        area: "부산 수영구",
        summary: "해운대 밤바다 루트와 함께 보기 좋은 부산 대표 야경 명소.",
        rating: 4.8,
        imageStyle: .night,
        imageAssetName: "log_busan_night",
        tags: ["부산", "야경", "해운대", "광안대교"],
        pinX: 0.56,
        pinY: 0.38
    )

    static let haeundaeBeach = MaplogSpot(
        id: "spot-haeundae-beach",
        name: "해운대해수욕장",
        category: "축제",
        area: "부산 해운대구",
        summary: "부산 바다축제와 밤바다 루트가 이어지는 대표 해변.",
        rating: 4.7,
        imageStyle: .ocean,
        imageAssetName: "event_ocean_film_hero",
        tags: ["부산", "축제", "해운대", "바다"],
        pinX: 0.48,
        pinY: 0.46
    )

    static let minrakWaterfrontPark = MaplogSpot(
        id: "spot-minrak-waterfront",
        name: "민락수변공원",
        category: "산책",
        area: "부산 수영구 민락동",
        summary: "광안대교 불빛을 따라 천천히 걷기 좋은 밤 산책 구간.",
        rating: 4.7,
        imageStyle: .night,
        imageAssetName: "search_busan_route",
        tags: ["부산", "광안리", "야경", "산책"],
        pinX: 0.62,
        pinY: 0.43
    )

    static let spots = [seoulTower, forestCafe, jejuOreum, aewolCoast, seongsuAlley, seoulForest, ttukseomRiverPark, busanMarket, gwanganBridgeNight, haeundaeBeach, minrakWaterfrontPark]

    /// 릴스에 기록된 장소를 중심으로 표시할 3km 내 주변 추천 목업입니다.
    static func nearbyRecommendations(around spot: MaplogSpot, withinKilometers: Int = 3) -> [MaplogSpot] {
        let neighborhood: String
        let area: String

        if spot.area.contains("제주") {
            neighborhood = "애월"
            area = "제주 제주시 애월읍"
        } else if spot.area.contains("부산") {
            neighborhood = "광안리"
            area = "부산 수영구"
        } else if spot.area.contains("종로") {
            neighborhood = "광화문"
            area = "서울 종로구"
        } else {
            neighborhood = "성수"
            area = "서울 성동구 성수동"
        }

        func clamped(_ value: Double) -> Double {
            min(max(value, 0.14), 0.86)
        }

        let radiusText = "\(withinKilometers)km 이내"

        return [
            MaplogSpot(
                id: "nearby-\(spot.id)-cafe",
                name: "\(neighborhood) 로스터리",
                category: "카페",
                area: area,
                summary: "\(radiusText)에서 잠깐 쉬어가기 좋은 로스터리 카페.",
                rating: 4.4,
                imageStyle: .cafe,
                imageAssetName: "photo_cafe",
                mapPinStyle: .cafe,
                tags: ["카페", neighborhood, "주변"],
                pinX: clamped(spot.pinX - 0.18),
                pinY: clamped(spot.pinY - 0.06)
            ),
            MaplogSpot(
                id: "nearby-\(spot.id)-restaurant",
                name: "\(neighborhood) 식탁",
                category: "음식점",
                area: area,
                summary: "\(radiusText)에서 여행 동선에 더하기 좋은 로컬 다이닝.",
                rating: 4.6,
                imageStyle: .cafe,
                imageAssetName: "nearby_dining",
                mapPinStyle: .restaurant,
                tags: ["음식점", neighborhood, "주변"],
                pinX: clamped(spot.pinX + 0.18),
                pinY: clamped(spot.pinY + 0.08)
            ),
            MaplogSpot(
                id: "nearby-\(spot.id)-event",
                name: "\(neighborhood) 주말 팝업",
                category: "행사",
                area: area,
                summary: "\(radiusText)에서 이번 주말만 열리는 전시와 로컬 팝업.",
                rating: 4.5,
                imageStyle: .city,
                imageAssetName: "log_seongsu_evening",
                mapPinStyle: .event,
                tags: ["행사", "전시", neighborhood, "주변"],
                pinX: clamped(spot.pinX + 0.15),
                pinY: clamped(spot.pinY - 0.18)
            ),
            MaplogSpot(
                id: "nearby-\(spot.id)-festival",
                name: "\(neighborhood) 불빛 축제",
                category: "축제",
                area: area,
                summary: "\(radiusText)에서 공연과 야간 조명을 즐길 수 있는 계절 축제.",
                rating: 4.7,
                imageStyle: .festival,
                imageAssetName: "event_ocean_film_hero",
                mapPinStyle: .festival,
                tags: ["축제", "야경", neighborhood, "주변"],
                pinX: clamped(spot.pinX - 0.05),
                pinY: clamped(spot.pinY + 0.18)
            )
        ]
    }

    static let gwanganriNightWalk = MaplogTrip(
        id: "trip-gwangan-night-walk",
        title: "광안리 나이트 워크",
        subtitle: "광안대교 불빛을 따라 민락수변공원까지 걷는 밤",
        location: "부산 수영구",
        duration: "약 1시간 10분",
        coverStyle: .night,
        spots: [gwanganBridgeNight, minrakWaterfrontPark],
        nearbySpots: [haeundaeBeach]
    )

    static let trips: [MaplogTrip] = [
        MaplogTrip(
            id: "trip-seoul-night",
            title: "서울라이트 광화문",
            subtitle: "빛의 향연이 펼쳐지는 밤 산책",
            location: "서울",
            duration: "오늘 진행 중",
            coverStyle: .night,
            spots: [seoulTower, forestCafe]
        ),
        MaplogTrip(
            id: "trip-jeju-green",
            title: "제주 서쪽 일몰 루트",
            subtitle: "새별오름에서 애월 바다까지 이어지는 저녁",
            location: "제주",
            duration: "약 2시간",
            coverStyle: .forest,
            spots: [jejuOreum, aewolCoast]
        ),
        MaplogTrip(
            id: "trip-busan-blue",
            title: "퇴근 후 성수 산책",
            subtitle: "성수 골목에서 서울숲과 한강까지 이어 걷는 저녁",
            location: "서울",
            duration: "약 2시간",
            coverStyle: .city,
            spots: [forestCafe, seongsuAlley, seoulForest, ttukseomRiverPark]
        ),
        gwanganriNightWalk
    ]

    static let logs: [TravelLog] = [
        TravelLog(id: "log-1", title: "광안리 나이트 워크", place: "광안대교 야경 포인트", date: "2026.06", note: "불이 켜진 광안대교를 보며 민락수변공원까지 천천히 걸었다.", imageStyle: .night, clips: 7, city: "Busan"),
        TravelLog(id: "log-2", title: "퇴근 후 성수 산책", place: "오우드 성수", date: "2026.05", note: "연무장길과 조용한 카페의 저녁 풍경을 짧게 기록했다.", imageStyle: .city, clips: 6, city: "Seoul"),
        TravelLog(id: "log-3", title: "새별오름 일몰", place: "새별오름", date: "2026.04", note: "억새길을 오르며 노을이 바뀌는 순간을 이어 담았다.", imageStyle: .forest, clips: 5, city: "Jeju")
    ]

    static let collections: [SavedCollection] = [
        SavedCollection(id: "collection-weekend", title: "주말에 가볼 곳", count: 12, styles: [.cafe, .city, .forest]),
        SavedCollection(id: "collection-night", title: "야경 맛집", count: 8, styles: [.night, .city]),
        SavedCollection(id: "collection-jeju", title: "제주 다시가기", count: 15, styles: [.forest, .ocean, .market])
    ]

    static let events: [FeaturedEvent] = [
        FeaturedEvent(id: "event-1", title: "2026 진주 정원박람", period: "2026. 6. 18. ~ 2026. 6. 21.", location: "진주", imageStyle: .festival, thumbnailAssetName: "event_jinju_garden", heroAssetName: "event_jinju_garden_hero"),
        FeaturedEvent(id: "event-2", title: "국제해양영화제", period: "2026. 6. 18. ~ 2026. 6. 21.", location: "부산", imageStyle: .ocean, thumbnailAssetName: "event_ocean_film", heroAssetName: "event_ocean_film_hero"),
        FeaturedEvent(id: "event-3", title: "강릉단오제", period: "2026. 6. 18. ~ 2026. 6. 25.", location: "강릉", imageStyle: .market, thumbnailAssetName: "event_gangneung_dano", heroAssetName: "event_gangneung_dano_hero"),
        FeaturedEvent(id: "event-4", title: "2026 부산바다도서", period: "2026. 6. 13. ~ 7. 5.", location: "부산", imageStyle: .temple, thumbnailAssetName: "event_busan_book", heroAssetName: "event_busan_book_hero")
    ]

    static let aiDigests: [AIDigest] = [
        AIDigest(
            id: "digest-naju",
            title: "빛바랜 대한실과 뒷마루 사이",
            badge: "여행기사",
            summary: "전라도 나주는 역사와 문화가 어우러진 매력적인 여행지입니다. 구석구석 시대의 정취와 학생들의 용기를 느껴보세요.",
            source: "지역 문화 기사 12건 요약",
            readTime: "3분",
            imageStyle: .palace,
            query: "경복궁",
            spot: jejuOreum,
            points: ["오전에는 조용한 골목 산책이 좋아요.", "전시 공간과 카페를 함께 묶으면 동선이 자연스럽습니다.", "사진 기록은 한옥 골목의 문과 처마 디테일을 중심으로 남겨보세요."]
        ),
        AIDigest(
            id: "digest-icheon",
            title: "흙이 빚어낸 천천한 도시",
            badge: "사용자 후기",
            summary: "이천은 도자기와 쌀로 유명한 도시예요. 색다른 도자 체험과 조용한 골목 산책을 함께 즐길 수 있어요.",
            source: "방문 후기 89개 요약",
            readTime: "2분",
            imageStyle: .market,
            query: "북촌",
            spot: busanMarket,
            points: ["체험형 장소는 예약 가능 시간을 먼저 확인하세요.", "점심 이후에는 카페와 시장 동선을 짧게 묶는 편이 좋습니다.", "도자기 체험 컷은 제작 과정과 완성 컷을 함께 찍으면 기록 완성도가 높아요."]
        )
    ]

    static let searchBusanNightPost = VlogPost(
        id: "search-busan-night-route",
        author: "@night.in.busan",
        title: "광안리에서 민락까지, 밤바다 7컷",
        caption: "광안대교 조명이 하나둘 켜지기 시작한 저녁, 민락수변공원에서 출발해 해변 산책로를 따라 걸었어요. 파도 소리와 보랏빛 불빛이 이어지는 구간은 1초씩만 담아도 충분히 분위기가 남더라고요. 잠시 벤치에 앉아 야경을 바라본 뒤, 사람들이 적어진 골목으로 돌아왔습니다.",
        place: gwanganBridgeNight,
        imageStyle: .night,
        likes: "2.4k",
        comments: "119",
        hashtags: ["광안리", "부산야경", "밤산책"]
    )

    static let posts: [VlogPost] = [
        VlogPost(
            id: "post-1",
            author: "@slow.seoul",
            title: "퇴근 후 성수, 여섯 개의 1초",
            caption: "연무장길을 걷다가 조용한 카페에서 하루를 마무리했어요.",
            place: forestCafe,
            imageStyle: .city,
            likes: "638",
            comments: "28",
            hashtags: ["성수산책", "퇴근후여행", "서울"]
        ),
        VlogPost(
            id: "post-2",
            author: "@jeju.oneday",
            title: "새별오름 일몰을 5초에 담으면",
            caption: "바람이 강했던 날, 억새길과 노을만 짧게 이어 남겼어요.",
            place: jejuOreum,
            imageStyle: .forest,
            likes: "1.8k",
            comments: "74",
            hashtags: ["새별오름", "제주일몰", "억새"]
        ),
        searchBusanNightPost
    ]

    static func routeTrip(for post: VlogPost) -> MaplogTrip {
        let baseTrip = baseTrip(for: post)
        let orderedSpots = orderedSpots(primarySpot: post.place, baseTrip: baseTrip)

        return MaplogTrip(
            id: "vlog-route-\(post.id)",
            title: post.title,
            subtitle: post.caption,
            location: post.place.area,
            duration: baseTrip.duration,
            coverStyle: post.imageStyle,
            spots: orderedSpots,
            nearbySpots: nearbyRecommendations(around: post.place)
        )
    }

    static func routeTrip(for spot: MaplogSpot) -> MaplogTrip {
        if spot.id == gwanganBridgeNight.id || spot.id == haeundaeBeach.id {
            return routeTrip(for: searchBusanNightPost)
        }

        if let matchingPost = posts.first(where: { $0.place.id == spot.id }) {
            return routeTrip(for: matchingPost)
        }

        let baseTrip = trips.first { trip in
            trip.spots.contains { $0.id == spot.id }
        } ?? trips[0]

        return MaplogTrip(
            id: "spot-route-\(spot.id)",
            title: "\(spot.name) 주변 코스",
            subtitle: "\(spot.category) 방문 전후로 들르기 좋은 장소를 묶었어요",
            location: spot.area,
            duration: baseTrip.duration,
            coverStyle: spot.imageStyle,
            spots: orderedSpots(primarySpot: spot, baseTrip: baseTrip),
            nearbySpots: nearbyRecommendations(around: spot)
        )
    }

    private static func baseTrip(for post: VlogPost) -> MaplogTrip {
        if post.id == "search-busan-night-route" {
            return MaplogTrip(
                id: "trip-busan-night-search",
                title: "해운대 밤바다 3컷",
                subtitle: "야경 명소를 따라 걷는 40분 코스",
                location: "부산",
                duration: "40분",
                coverStyle: .ocean,
                spots: [gwanganBridgeNight, haeundaeBeach]
            )
        }

        if post.id == "post-1", let seongsuTrip = trips.first(where: { $0.id == "trip-busan-blue" }) {
            return seongsuTrip
        }

        if post.id == "post-2", let palaceTrip = trips.first(where: { $0.id == "trip-jeju-green" }) {
            return palaceTrip
        }

        return trips.first { trip in
            trip.spots.contains { $0.id == post.place.id }
        } ?? trips[2]
    }

    private static func orderedSpots(primarySpot: MaplogSpot, baseTrip: MaplogTrip) -> [MaplogSpot] {
        let secondarySpots = baseTrip.spots.filter { $0.id != primarySpot.id }
        let routeSpots = [primarySpot] + secondarySpots
        return Array(routeSpots.prefix(4))
    }
}
