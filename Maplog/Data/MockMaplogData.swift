import Foundation

enum MockMaplogData {
    static let spotlightEvent = FeaturedEvent(
        id: "event-seoul-light-gwanghwamun",
        title: "서울라이트 광화문 빛의 향연",
        period: "2026. 6. 19. ~ 2026. 6. 22.",
        location: "서울",
        imageStyle: .palace
    )

    static let seoulTower = MaplogSpot(
        id: "spot-seoul-tower",
        name: "서울라이트 광화문",
        category: "야경",
        area: "서울 종로구",
        summary: "도심 속에서 펼쳐지는 화려한 미디어 아트. 오늘 밤 광화문 광장에서 특별한 추억을 만들기 좋은 장소.",
        rating: 4.7,
        imageStyle: .night,
        tags: ["성수동", "팝업스토어", "서울숲"],
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
        tags: ["커피", "산책", "휴식"],
        pinX: 0.32,
        pinY: 0.58
    )

    static let jejuOreum = MaplogSpot(
        id: "spot-jeju-oreum",
        name: "경복궁",
        category: "궁궐",
        area: "서울 종로구",
        summary: "게시물 24개와 주변 명소가 이어지는 도심 궁궐 루트의 중심 장소.",
        rating: 4.9,
        imageStyle: .palace,
        tags: ["문화", "한옥", "루트"],
        pinX: 0.70,
        pinY: 0.46
    )

    static let busanMarket = MaplogSpot(
        id: "spot-busan-market",
        name: "북촌 한옥마을",
        category: "문화",
        area: "서울 종로구",
        summary: "경복궁 경로 주변에서 함께 둘러보기 좋은 한옥 골목.",
        rating: 4.6,
        imageStyle: .alley,
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
        tags: ["부산", "축제", "해운대", "바다"],
        pinX: 0.48,
        pinY: 0.46
    )

    static let spots = [seoulTower, forestCafe, jejuOreum, busanMarket, gwanganBridgeNight, haeundaeBeach]

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
            title: "궁궐과 골목 루트",
            subtitle: "경복궁에서 북촌까지 이어지는 산책",
            location: "서울",
            duration: "게시물 24개",
            coverStyle: .palace,
            spots: [jejuOreum, busanMarket]
        ),
        MaplogTrip(
            id: "trip-busan-blue",
            title: "성수 팝업 투어",
            subtitle: "카페와 팝업스토어 4곳 완벽 정리",
            location: "서울",
            duration: "45분",
            coverStyle: .city,
            spots: [busanMarket, forestCafe]
        )
    ]

    static let logs: [TravelLog] = [
        TravelLog(id: "log-1", title: "도심 탐험", place: "서울라이트 광화문", date: "2024.05", note: "빛바랜 대한실과 뒷마루 사이를 걷는 기분.", imageStyle: .night, clips: 3, city: "Seoul"),
        TravelLog(id: "log-2", title: "네온 나이트", place: "성수동", date: "2024.04", note: "성수동 팝업스토어부터 비밀스러운 카페까지.", imageStyle: .city, clips: 5, city: "Tokyo"),
        TravelLog(id: "log-3", title: "궁궐 산책", place: "경복궁", date: "2024.03", note: "경로 주변 명소를 따라 천천히 걸었다.", imageStyle: .palace, clips: 4, city: "Seoul")
    ]

    static let collections: [SavedCollection] = [
        SavedCollection(id: "collection-weekend", title: "주말에 가볼 곳", count: 12, styles: [.cafe, .city, .forest]),
        SavedCollection(id: "collection-night", title: "야경 맛집", count: 8, styles: [.night, .city]),
        SavedCollection(id: "collection-jeju", title: "제주 다시가기", count: 15, styles: [.forest, .ocean, .market])
    ]

    static let events: [FeaturedEvent] = [
        FeaturedEvent(id: "event-1", title: "2026 진주 정원박람", period: "2026. 6. 18. ~ 2026. 6. 21.", location: "진주", imageStyle: .festival, thumbnailAssetName: "event_jinju_garden"),
        FeaturedEvent(id: "event-2", title: "국제해양영화제", period: "2026. 6. 18. ~ 2026. 6. 21.", location: "부산", imageStyle: .ocean, thumbnailAssetName: "event_ocean_film"),
        FeaturedEvent(id: "event-3", title: "강릉단오제", period: "2026. 6. 18. ~ 2026. 6. 25.", location: "강릉", imageStyle: .market, thumbnailAssetName: "event_gangneung_dano"),
        FeaturedEvent(id: "event-4", title: "2026 부산바다도서", period: "2026. 6. 13. ~ 7. 5.", location: "부산", imageStyle: .temple, thumbnailAssetName: "event_busan_book")
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
        author: "@busan_runner",
        title: "해운대 밤바다 3컷",
        caption: "광안대교가 켜지는 시간에 맞춰 걷기 좋은 짧은 야경 루트.",
        place: gwanganBridgeNight,
        imageStyle: .ocean,
        likes: "1.2k",
        comments: "86",
        hashtags: ["야경명소", "부산", "해운대"]
    )

    static let posts: [VlogPost] = [
        VlogPost(
            id: "post-1",
            author: "@seoul_vibe",
            title: "성수동 힙플 투어 4컷 완벽 정리",
            caption: "꼭 가봐야 할 팝업스토어부터 비밀스러운 카페까지.",
            place: forestCafe,
            imageStyle: .city,
            likes: "1.2k",
            comments: "342",
            hashtags: ["성수동", "팝업스토어", "서울숲"]
        ),
        VlogPost(
            id: "post-2",
            author: "@maplog",
            title: "경복궁 주변 경로 저장",
            caption: "궁궐에서 북촌까지 걸어서 따라가기 좋은 루트.",
            place: jejuOreum,
            imageStyle: .palace,
            likes: "842",
            comments: "91",
            hashtags: ["궁궐", "한옥", "서울여행"]
        )
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
            spots: orderedSpots
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
            spots: orderedSpots(primarySpot: spot, baseTrip: baseTrip)
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
        return Array(routeSpots.prefix(3))
    }
}
