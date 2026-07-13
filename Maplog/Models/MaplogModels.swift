import Foundation
import Combine

enum PhotoStyle: String, CaseIterable, Hashable {
    case mountain
    case ocean
    case city
    case night
    case cafe
    case forest
    case temple
    case market
    case festival
    case palace
    case alley

    var symbol: String {
        switch self {
        case .mountain: return "mountain.2.fill"
        case .ocean: return "water.waves"
        case .city: return "building.2.fill"
        case .night: return "moon.stars.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .forest: return "leaf.fill"
        case .temple: return "sparkles"
        case .market: return "bag.fill"
        case .festival: return "party.popper.fill"
        case .palace: return "building.columns.fill"
        case .alley: return "figure.walk"
        }
    }

    var assetName: String {
        "photo_\(rawValue)"
    }
}

enum MapPinStyle: Hashable {
    /// Maplog 릴스에 실제로 기록된 장소입니다. 사진 썸네일로 표시합니다.
    case recorded
    case cafe
    case restaurant
    case event
    case festival
}

struct MaplogSpot: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let area: String
    let summary: String
    let rating: Double
    let imageStyle: PhotoStyle
    /// 장소 카드와 지도 핀에 사용할 실제 사진 에셋입니다. 없으면 카테고리 기본 이미지를 사용합니다.
    let imageAssetName: String?
    let mapPinStyle: MapPinStyle
    let tags: [String]
    let pinX: Double
    let pinY: Double

    init(
        id: String,
        name: String,
        category: String,
        area: String,
        summary: String,
        rating: Double,
        imageStyle: PhotoStyle,
        imageAssetName: String? = nil,
        mapPinStyle: MapPinStyle = .recorded,
        tags: [String],
        pinX: Double,
        pinY: Double
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.area = area
        self.summary = summary
        self.rating = rating
        self.imageStyle = imageStyle
        self.imageAssetName = imageAssetName
        self.mapPinStyle = mapPinStyle
        self.tags = tags
        self.pinX = pinX
        self.pinY = pinY
    }
}

struct MaplogTrip: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let location: String
    let duration: String
    let coverStyle: PhotoStyle
    let spots: [MaplogSpot]
    /// 경로에 포함되지는 않지만 지도에서 함께 확인할 수 있는 주변 추천 장소입니다.
    let nearbySpots: [MaplogSpot]

    init(
        id: String,
        title: String,
        subtitle: String,
        location: String,
        duration: String,
        coverStyle: PhotoStyle,
        spots: [MaplogSpot],
        nearbySpots: [MaplogSpot] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.location = location
        self.duration = duration
        self.coverStyle = coverStyle
        self.spots = spots
        self.nearbySpots = nearbySpots
    }
}

struct TravelLog: Identifiable, Hashable {
    let id: String
    let title: String
    let place: String
    let date: String
    let note: String
    let imageStyle: PhotoStyle
    let clips: Int
    let city: String
}

struct SavedCollection: Identifiable, Hashable {
    let id: String
    let title: String
    let count: Int
    let styles: [PhotoStyle]
}

struct ComposerDraft: Hashable {
    let placeName: String
    let title: String?
    let mood: String
    let rating: Int
    let note: String
    let imageStyle: PhotoStyle
    let sourceDraftID: String?
    let clipCount: Int
    let locationTags: [MaplogDraftLocationTag]
    let hashtags: [String]

    init(
        placeName: String,
        title: String? = nil,
        mood: String,
        rating: Int,
        note: String,
        imageStyle: PhotoStyle,
        sourceDraftID: String? = nil,
        clipCount: Int = 3,
        locationTags: [MaplogDraftLocationTag] = [],
        hashtags: [String] = []
    ) {
        self.placeName = placeName
        self.title = title
        self.mood = mood
        self.rating = rating
        self.note = note
        self.imageStyle = imageStyle
        self.sourceDraftID = sourceDraftID
        self.clipCount = max(clipCount, 1)
        self.locationTags = locationTags
        self.hashtags = hashtags
    }

    var displayPlace: String {
        let trimmedPlace = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPlace.isEmpty ? "새 맵로그" : trimmedPlace
    }

    var displayTitle: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? displayPlace : trimmedTitle
    }
}

struct MaplogDraftLocationTag: Hashable {
    let id: String
    let name: String
    let timeRange: String
    let style: PhotoStyle
}

struct MaplogDraft: Identifiable, Hashable {
    let id: String
    let title: String
    let placeName: String
    let note: String
    let visibility: String
    let imageStyle: PhotoStyle
    let clipCount: Int
    let locationCount: Int
    let updatedAtText: String
    let clipStyles: [PhotoStyle]
    let locationTags: [MaplogDraftLocationTag]
    let hashtags: [String]

    init(
        id: String,
        title: String,
        placeName: String,
        note: String,
        visibility: String,
        imageStyle: PhotoStyle,
        clipCount: Int,
        locationCount: Int,
        updatedAtText: String,
        clipStyles: [PhotoStyle] = [],
        locationTags: [MaplogDraftLocationTag] = [],
        hashtags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.placeName = placeName
        self.note = note
        self.visibility = visibility
        self.imageStyle = imageStyle
        self.clipCount = clipCount
        self.locationCount = locationCount
        self.updatedAtText = updatedAtText
        self.clipStyles = clipStyles
        self.locationTags = locationTags
        self.hashtags = hashtags
    }

    var metadata: String {
        "\(clipCount)컷 · 위치 \(locationCount)개 · \(visibility)"
    }

    var composerDraft: ComposerDraft {
        ComposerDraft(
            placeName: placeName,
            title: title,
            mood: visibility,
            rating: 5,
            note: note,
            imageStyle: imageStyle,
            sourceDraftID: id,
            clipCount: clipCount,
            locationTags: locationTags,
            hashtags: hashtags
        )
    }
}

struct FeaturedEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let period: String
    let location: String
    let imageStyle: PhotoStyle
    let thumbnailAssetName: String?
    let heroAssetName: String?

    init(
        id: String,
        title: String,
        period: String,
        location: String,
        imageStyle: PhotoStyle,
        thumbnailAssetName: String? = nil,
        heroAssetName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.period = period
        self.location = location
        self.imageStyle = imageStyle
        self.thumbnailAssetName = thumbnailAssetName
        self.heroAssetName = heroAssetName
    }
}

struct VlogPost: Identifiable, Hashable {
    let id: String
    let author: String
    let title: String
    let caption: String
    let place: MaplogSpot
    let imageStyle: PhotoStyle
    let likes: String
    let comments: String
    let hashtags: [String]
}

struct VlogComment: Identifiable, Hashable {
    let id: String
    let author: String
    let body: String
    let timeText: String
    let isMine: Bool
    let attachmentData: Data?

    init(
        id: String,
        author: String,
        body: String,
        timeText: String,
        isMine: Bool,
        attachmentData: Data? = nil
    ) {
        self.id = id
        self.author = author
        self.body = body
        self.timeText = timeText
        self.isMine = isMine
        self.attachmentData = attachmentData
    }
}

struct AIDigest: Identifiable, Hashable {
    let id: String
    let title: String
    let badge: String
    let summary: String
    let source: String
    let readTime: String
    let imageStyle: PhotoStyle
    let query: String
    let spot: MaplogSpot
    let points: [String]
}

struct MaplogUserProfile: Hashable {
    var displayName: String
    var location: String
    var bio: String
    var isPublic: Bool
    var avatarStyle: PhotoStyle
}

struct MaplogNotificationSettings: Hashable {
    var pushNotificationsEnabled: Bool
    var serviceAnnouncementsEnabled: Bool
}

enum MaplogLocationPermissionStatus: Hashable {
    case notDetermined
    case allowed
    case skipped

    var isAllowed: Bool {
        self == .allowed
    }
}

struct MaplogServicePass: Identifiable, Hashable {
    let title: String
    let issuedTitle: String
    let badge: String
    let summary: String
    let heroStyle: PhotoStyle

    var id: String { title }
}

final class MaplogSessionStore: ObservableObject {
    static let initialLikedVlogPostIDs: Set<String> = ["post-1"]

    @Published private(set) var profile = MaplogUserProfile(
        displayName: "채림",
        location: "Seoul",
        bio: "모험을 사랑하는 여행자 ✈️ 새로운 맵로그를 찾아서",
        isPublic: true,
        avatarStyle: .night
    )
    @Published private(set) var publishedLogs: [TravelLog] = []
    @Published private(set) var savedDrafts: [MaplogDraft] = []
    @Published private(set) var savedRoutes: [MaplogTrip] = []
    @Published private(set) var savedSpots: [MaplogSpot] = []
    @Published private(set) var visitChecklistSpots: [MaplogSpot] = []
    @Published private(set) var savedEvents: [FeaturedEvent] = []
    @Published private(set) var savedDigestIDs: Set<String> = []
    @Published private(set) var issuedServicePasses: [MaplogServicePass] = []
    @Published private(set) var vlogCommentsByPostID: [String: [VlogComment]] = [:]
    @Published private(set) var likedVlogPostIDs: Set<String> = MaplogSessionStore.initialLikedVlogPostIDs
    @Published private(set) var followedAuthorIDs: Set<String> = []
    @Published private(set) var blockedAuthorIDs: Set<String> = []
    @Published private(set) var notificationSettings = MaplogNotificationSettings(
        pushNotificationsEnabled: true,
        serviceAnnouncementsEnabled: true
    )
    @Published private(set) var locationPermissionStatus: MaplogLocationPermissionStatus = .notDetermined
    @Published private(set) var readNoticeIDs: Set<String> = []
    @Published private(set) var deletedNoticeIDs: Set<String> = []
    @Published private(set) var recentSearchTerms: [String] = []
    @Published private(set) var activeRouteID: String?
    @Published private(set) var routeProgressByRouteID: [String: Int] = [:]

    func updateProfile(_ profile: MaplogUserProfile) {
        self.profile = profile
    }

    func setPushNotificationsEnabled(_ isEnabled: Bool) {
        notificationSettings.pushNotificationsEnabled = isEnabled
    }

    func setServiceAnnouncementsEnabled(_ isEnabled: Bool) {
        notificationSettings.serviceAnnouncementsEnabled = isEnabled
    }

    func allowLocationPermission() {
        locationPermissionStatus = .allowed
    }

    func skipLocationPermission() {
        locationPermissionStatus = .skipped
    }

    func markNoticeRead(id: String) {
        readNoticeIDs.insert(id)
    }

    func markAllNoticesRead(ids: [String]) {
        readNoticeIDs.formUnion(ids)
    }

    func deleteNotice(id: String) {
        deletedNoticeIDs.insert(id)
    }

    func recordSearch(term: String) {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else {
            return
        }

        recentSearchTerms.removeAll { $0.localizedCaseInsensitiveCompare(trimmedTerm) == .orderedSame }
        recentSearchTerms.insert(trimmedTerm, at: 0)
        if recentSearchTerms.count > 8 {
            recentSearchTerms = Array(recentSearchTerms.prefix(8))
        }
    }

    func clearRecentSearchTerms() {
        recentSearchTerms.removeAll()
    }

    func hasIssuedServicePass(title: String) -> Bool {
        issuedServicePasses.contains { $0.title == title }
    }

    func issueServicePass(_ pass: MaplogServicePass) {
        guard !hasIssuedServicePass(title: pass.title) else {
            return
        }

        issuedServicePasses.insert(pass, at: 0)
    }

    func revokeServicePass(title: String) {
        issuedServicePasses.removeAll { $0.title == title }
    }

    func vlogComments(for postID: String) -> [VlogComment] {
        vlogCommentsByPostID[postID, default: []]
    }

    func vlogCommentCount(for postID: String) -> Int {
        vlogCommentsByPostID[postID, default: []].count
    }

    @discardableResult
    func addVlogComment(
        postID: String,
        body: String,
        attachmentData: Data? = nil
    ) -> VlogComment? {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty || attachmentData != nil else {
            return nil
        }

        let comment = VlogComment(
            id: "comment-\(UUID().uuidString)",
            author: profile.displayName,
            body: trimmedBody,
            timeText: "방금",
            isMine: true,
            attachmentData: attachmentData
        )

        vlogCommentsByPostID[postID, default: []].insert(comment, at: 0)
        return comment
    }

    func hasLikedVlogPost(_ post: VlogPost) -> Bool {
        likedVlogPostIDs.contains(post.id)
    }

    func wasInitiallyLikedVlogPost(_ post: VlogPost) -> Bool {
        Self.initialLikedVlogPostIDs.contains(post.id)
    }

    func likeVlogPost(_ post: VlogPost) {
        likedVlogPostIDs.insert(post.id)
    }

    func unlikeVlogPost(_ post: VlogPost) {
        likedVlogPostIDs.remove(post.id)
    }

    func isFollowing(author: String) -> Bool {
        followedAuthorIDs.contains(author)
    }

    func follow(author: String) {
        guard !blockedAuthorIDs.contains(author) else {
            return
        }

        followedAuthorIDs.insert(author)
    }

    func unfollow(author: String) {
        followedAuthorIDs.remove(author)
    }

    func isBlocked(author: String) -> Bool {
        blockedAuthorIDs.contains(author)
    }

    func block(author: String) {
        blockedAuthorIDs.insert(author)
        followedAuthorIDs.remove(author)
    }

    func unblock(author: String) {
        blockedAuthorIDs.remove(author)
    }

    func publish(draft: ComposerDraft) -> TravelLog {
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayPlace = draft.displayPlace
        let publishedLog = TravelLog(
            id: "published-\(UUID().uuidString)",
            title: draft.displayTitle,
            place: displayPlace,
            date: currentMonthString,
            note: note.isEmpty ? "\(displayPlace)에서 남긴 오늘의 맵로그입니다." : note,
            imageStyle: draft.imageStyle,
            clips: draft.clipCount,
            city: cityName(for: displayPlace)
        )

        publishedLogs.insert(publishedLog, at: 0)
        removeSavedDraft(matching: draft)
        return publishedLog
    }

    func saveDraft(_ draft: MaplogDraft) {
        if let index = savedDrafts.firstIndex(where: { $0.id == draft.id }) {
            savedDrafts[index] = draft
        } else {
            savedDrafts.insert(draft, at: 0)
        }
    }

    func deleteDraft(_ draft: MaplogDraft) {
        savedDrafts.removeAll { $0.id == draft.id }
    }

    private func removeSavedDraft(matching draft: ComposerDraft) {
        if let sourceDraftID = draft.sourceDraftID {
            savedDrafts.removeAll { $0.id == sourceDraftID }
            return
        }

        savedDrafts.removeAll {
            $0.composerDraft.displayTitle == draft.displayTitle
                && $0.composerDraft.displayPlace == draft.displayPlace
        }
    }

    func deleteLog(_ log: TravelLog) {
        publishedLogs.removeAll { $0.id == log.id }
    }

    func hasSavedRoute(_ trip: MaplogTrip) -> Bool {
        savedRoutes.contains { $0.id == trip.id }
    }

    @discardableResult
    func saveRoute(_ trip: MaplogTrip) -> Bool {
        guard !hasSavedRoute(trip) else {
            return false
        }

        savedRoutes.insert(trip, at: 0)
        return true
    }

    @discardableResult
    func removeSavedRoute(_ trip: MaplogTrip) -> Bool {
        guard let index = savedRoutes.firstIndex(where: { $0.id == trip.id }) else {
            return false
        }

        savedRoutes.remove(at: index)
        return true
    }

    func clearSavedRoutes() {
        savedRoutes.removeAll()
    }

    func hasVisitChecklistSpot(_ spot: MaplogSpot) -> Bool {
        visitChecklistSpots.contains { $0.id == spot.id }
    }

    @discardableResult
    func addVisitChecklistSpot(_ spot: MaplogSpot) -> Bool {
        guard !hasVisitChecklistSpot(spot) else {
            return false
        }

        visitChecklistSpots.insert(spot, at: 0)
        return true
    }

    @discardableResult
    func removeVisitChecklistSpot(_ spot: MaplogSpot) -> Bool {
        guard let index = visitChecklistSpots.firstIndex(where: { $0.id == spot.id }) else {
            return false
        }

        visitChecklistSpots.remove(at: index)
        return true
    }

    func isGuidingRoute(_ trip: MaplogTrip) -> Bool {
        activeRouteID == trip.id
    }

    func routeProgressIndex(for trip: MaplogTrip) -> Int {
        let lastIndex = max(trip.spots.count - 1, 0)
        let progressIndex = routeProgressByRouteID[trip.id, default: 0]
        return min(max(progressIndex, 0), lastIndex)
    }

    func startRoute(_ trip: MaplogTrip) {
        activeRouteID = trip.id
        routeProgressByRouteID[trip.id] = routeProgressIndex(for: trip)
    }

    @discardableResult
    func advanceRoute(_ trip: MaplogTrip) -> Bool {
        guard isGuidingRoute(trip) else {
            startRoute(trip)
            return true
        }

        let currentIndex = routeProgressIndex(for: trip)
        let lastIndex = max(trip.spots.count - 1, 0)
        guard currentIndex < lastIndex else {
            return false
        }

        routeProgressByRouteID[trip.id] = currentIndex + 1
        return true
    }

    func stopRoute(_ trip: MaplogTrip) {
        if activeRouteID == trip.id {
            activeRouteID = nil
        }
        routeProgressByRouteID[trip.id] = 0
    }

    func hasSavedSpot(_ spot: MaplogSpot) -> Bool {
        savedSpots.contains { $0.id == spot.id }
    }

    @discardableResult
    func saveSpot(_ spot: MaplogSpot) -> Bool {
        guard !hasSavedSpot(spot) else {
            return false
        }

        savedSpots.insert(spot, at: 0)
        return true
    }

    @discardableResult
    func removeSavedSpot(_ spot: MaplogSpot) -> Bool {
        guard let index = savedSpots.firstIndex(where: { $0.id == spot.id }) else {
            return false
        }

        savedSpots.remove(at: index)
        return true
    }

    func hasSavedEvent(_ event: FeaturedEvent) -> Bool {
        savedEvents.contains { $0.id == event.id }
    }

    @discardableResult
    func saveEvent(_ event: FeaturedEvent) -> Bool {
        guard !hasSavedEvent(event) else {
            return false
        }

        savedEvents.insert(event, at: 0)
        return true
    }

    @discardableResult
    func removeSavedEvent(_ event: FeaturedEvent) -> Bool {
        guard let index = savedEvents.firstIndex(where: { $0.id == event.id }) else {
            return false
        }

        savedEvents.remove(at: index)
        return true
    }

    func hasSavedDigest(_ digest: AIDigest) -> Bool {
        savedDigestIDs.contains(digest.id)
    }

    func saveDigest(_ digest: AIDigest) {
        savedDigestIDs.insert(digest.id)
    }

    func removeSavedDigest(_ digest: AIDigest) {
        savedDigestIDs.remove(digest.id)
    }

    private var currentMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM"
        return formatter.string(from: Date())
    }

    private func cityName(for place: String) -> String {
        if place.contains("제주") { return "Jeju" }
        if place.contains("부산") { return "Busan" }
        if place.contains("강릉") { return "Gangneung" }
        if place.contains("전주") { return "Jeonju" }
        return "Seoul"
    }
}
