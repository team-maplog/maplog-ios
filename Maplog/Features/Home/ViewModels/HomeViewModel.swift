//HomeView
//  → “관광 불러와 줘” 요청
//HomeViewModel
//  → Repository로 API 호출
//  → 관광 데이터를 카드용 데이터와 상태로 변환
//HomeView
//  ← 변경된 상태를 관찰하고 화면을 다시 그림

//HomeTourismCardViewData
//- HomeViewModel이 Tourism을 카드 표시용으로 변환한 결과
//- HomeView가 카드 하나를 그릴 때 사용
//
//HomeTourismSectionState
//- HomeViewModel이 현재 관광 영역의 상태를 표현
//- HomeView가 loading / content / empty / failed 중 무엇을 보여 줄지 결정할 때 사용

//loadInitialTourisms()
//→ Repository에 첫 페이지 요청
//→ 성공이면 카드 데이터 생성
//→ empty / content / failed 상태로 변경

//서버 JSON
//TourismDTO
//↓ Repository
//Tourism
//↓ HomeViewModel의 makeCardViewData
//HomeTourismCardViewData
//↓ HomeView
//화면 카드

//TourismDTO
//- 서버가 보내는 원본 형식
//- 날짜: String
//- 이미지: String
//- 필드명: thumbnailUrl, content
//
//Tourism
//- 앱 내부에서 공통으로 쓰기 좋은 형식
//- 날짜: Date
//- 이미지: URL?
//- region: String?
//
//HomeTourismCardViewData
//- 홈 카드가 바로 그리기 좋은 형식
//- title: String
//- locationText: String
//- periodText: String
//- poster: 세로형 원본 이미지와 비율
//View가 “판단·변환”하지 않고, 받은 값을 “표시”만 하게 만들기 위해서

//region: String? → locationText: String, Date → periodText: String이라는 분명한 변환이 있으므로 HomeTourismCardViewData를 두는 게 좋음
//ViewModel은 Repository에게 Tourism을 받아서, 특정 화면이 바로 표시할 수 있는 상태와 문자열

import AVFoundation
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var tourismState: HomeTourismSectionState = .idle
    private var tourismsLoadedAt: Date?
    private let now: () -> Date
    @Published private(set) var reelState: HomeReelSectionState = .idle
    @Published private var thumbnailDataByReelID: [Int64: Data] = [:] // [로그 ID: 해당 썸네일 이미지 원본 Data]
    @Published private var thumbnailLoadingIDs: Set<Int64> = [] //현재 네트워크 요청 중인 로그 ID 모음
    @Published private var authorProfileImageDataByReelID: [Int64: Data] = [:]
    @Published private var authorProfileImageLoadingIDs: Set<Int64> = []
    @Published private(set) var activePlaybackReelID: Int64? // 현재 재생 대상으로 선택된 릴스
    @Published private(set) var playbackLoadingReelID: Int64? // 영상을 다운로드 중인 릴스
    @Published private(set) var playbackFailedReelID: Int64? // 영상 다운로드·재생 준비에 실패한 릴스
    @Published private(set) var reelPlaybackProgress: Double = 0 // 재생 진행 바 진행률
    @Published private(set) var likeUpdatingReelIDs = Set<Int64>()
    @Published private(set) var saveUpdatingReelIDs = Set<Int64>()
    @Published private(set) var interactionError: ErrorPresentation?
    private var pendingPlaybackStartTimeMillis: Int64 = 0 /// 현재 하나만 존재하는 플레이어가 준비된 뒤 이동할 목표 시점
    // 같은 로그를 닫았다 다시 열어도 이전 다운로드·seek 완료가 새 요청을 덮어쓰지 않게 한다.
    private var playbackLoadID: UUID?
    private var playbackSeekID: UUID?

    private let tourismRepository: any TourismRepository // TourismRepository protocol을 만족하는 어떤 실제 객체 하나(DefaultTourismRepository 객체가 들어감)
    private let logReelRepository: any LogReelRepository
    private let logInteractionRepository: any LogInteractionRepository
    private let logMediaRepository: any LogMediaRepository
    private let profileRepository: any ProfileRepository
    private let playbackService: any VideoPlaybackService
    private var failedInteraction: FailedInteraction?

    private enum FailedInteraction {
        case like(logID: Int64, isLiked: Bool)
        case save(logID: Int64, isSaved: Bool)
    }

    init(
        tourismRepository: any TourismRepository,
        logReelRepository: any LogReelRepository,
        logInteractionRepository: any LogInteractionRepository,
        logMediaRepository: any LogMediaRepository,
        profileRepository: any ProfileRepository,
        playbackService: any VideoPlaybackService,
        now: @escaping () -> Date = { Date() }
    ) { // HomeViewModel을 만들 때 Repository를 반드시 전달받게 함
        self.tourismRepository = tourismRepository
        self.now = now
        self.logReelRepository = logReelRepository
        self.logInteractionRepository = logInteractionRepository
        self.logMediaRepository = logMediaRepository
        self.profileRepository = profileRepository
        self.playbackService = playbackService
    }

    func loadInitialTourisms() async {
        guard tourismState != .loading, !hasFreshTourismCards else {
            return
        }

        if case .content = tourismState {
            await refreshTourisms(policy: .cached)
            return
        }

        tourismState = .loading

        do {
            let cards = try await fetchTourismCards()
            try Task.checkCancellation()
            tourismsLoadedAt = now()
            tourismState = cards.isEmpty ? .empty : .content(cards)
        } catch is CancellationError {
            tourismState = .idle
            return
        } catch {
            tourismState = .failed(TourismErrorPolicy.presentation(for: error))
        }
    }

    private var hasFreshTourismCards: Bool {
        guard let tourismsLoadedAt else { return false }
        let instant = now()
        let age = instant.timeIntervalSince(tourismsLoadedAt)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return age >= 0 && age < 600
            && calendar.isDate(tourismsLoadedAt, inSameDayAs: instant)
    }

    func retryInitialTourisms() async {
        guard tourismState != .loading else {
            return
        }

        tourismsLoadedAt = nil
        tourismState = .idle
        await loadInitialTourisms()
    }

    func loadInitialReels() async {
        guard reelState == .idle else {
            return
        }

        reelState = .loading

        do {
            let reels = try await fetchReelViewData()

            reelState = reels.isEmpty
                ? .empty
                : .content(reels)

        } catch is CancellationError {
            reelState = .idle

        } catch {
            reelState = .failed(
                HomeReelErrorPolicy.presentation(for: error)
            )
        }
    }

    func thumbnailData(for reelID: Int64) -> Data? {
        thumbnailDataByReelID[reelID]
    }

    func isLoadingThumbnail(for reelID: Int64) -> Bool {
        thumbnailLoadingIDs.contains(reelID)
    }

    func authorProfileImageData(
        for reelID: Int64
    ) -> Data? {
        authorProfileImageDataByReelID[reelID]
    }

    func loadAuthorProfileImage(
        for reel: HomeReelViewData
    ) async {
        guard let profileImageURL = reel.authorProfileImageURL,
              authorProfileImageDataByReelID[reel.id] == nil,
              !authorProfileImageLoadingIDs.contains(reel.id)
        else {
            return
        }

        authorProfileImageLoadingIDs.insert(reel.id)

        defer {
            authorProfileImageLoadingIDs.remove(reel.id)
        }

        do {
            let data = try await profileRepository.fetchImageData(
                from: profileImageURL
            )

            guard !Task.isCancelled else {
                return
            }

            authorProfileImageDataByReelID[reel.id] = data
        } catch {
            // 프로필 사진 실패는 릴스 피드 실패가 아니므로 이니셜 fallback을 유지한다.
            return
        }
    }

    func loadThumbnail(for reelID: Int64) async {
        guard thumbnailDataByReelID[reelID] == nil,
              !thumbnailLoadingIDs.contains(reelID) else {
            return
        }

        thumbnailLoadingIDs.insert(reelID)

        defer {
            thumbnailLoadingIDs.remove(reelID)
        }

        do {
            let data = try await logMediaRepository.fetchThumbnailData(
                logID: reelID
            )

            guard !Task.isCancelled else {
                return
            }

            thumbnailDataByReelID[reelID] = data

        } catch is CancellationError {
            return

        } catch {
            // 썸네일 하나의 실패가 홈 피드 전체 실패는 아니므로,
            // 다음 화면 단계에서 기본 이미지로 표시한다.
        }
    }

    func player(for reelID: Int64) -> AVPlayer? {
        guard activePlaybackReelID == reelID,
              playbackLoadingReelID != reelID,
              playbackFailedReelID != reelID
        else {
            return nil
        }

        return playbackService.player
    }

    func isLoadingPlayback(for reelID: Int64) -> Bool {
        playbackLoadingReelID == reelID
    }

    func hasPlaybackFailed(for reelID: Int64) -> Bool {
        playbackFailedReelID == reelID
    }

    func activatePlayback(
        for reelID: Int64
    ) async {
        await startPlayback(
            for: reelID,
            from: 0
        )
    }

    func playReel(
        withID reelID: Int64,
        from startTimeMillis: Int64
    ) async {
        await startPlayback(
            for: reelID,
            from: startTimeMillis
        )
    }

    private func startPlayback(
        for reelID: Int64,
        from startTimeMillis: Int64
    ) async {
        let safeStartTimeMillis = max(
            startTimeMillis,
            0
        )

        pendingPlaybackStartTimeMillis = safeStartTimeMillis

        /// 이미 같은 영상이 준비돼 있으면 다운로드를 다시 하지 않고 즉시 이동·재생
        if activePlaybackReelID == reelID,
           playbackLoadingReelID == nil,
           playbackFailedReelID != reelID,
           playbackService.player.currentItem != nil {
            seekAndPlay(
                for: reelID,
                from: safeStartTimeMillis
            )
            return
        }

        /// 같은 영상을 다운로드 중이라면 목표 시점만 갱신한다.
        /// 다운로드가 끝나면 아래 do 블록에서 가장 최근 시점으로 이동한다.
        if activePlaybackReelID == reelID,
           playbackLoadingReelID == reelID {
            return
        }

        playbackService.stop()
        let loadID = UUID()
        playbackLoadID = loadID
        playbackSeekID = nil

        activePlaybackReelID = reelID
        reelPlaybackProgress = 0
        playbackLoadingReelID = reelID
        playbackFailedReelID = nil

        do {
            let fileURL = try await logMediaRepository.fetchPlaybackFileURL(
                logID: reelID
            )

            try Task.checkCancellation()
            guard playbackLoadID == loadID,
                  activePlaybackReelID == reelID
            else {
                return
            }

            playbackService.loadVideo(
                at: fileURL
            )

            playbackService.observeProgress { [weak self] progress in
                guard let self,
                      self.activePlaybackReelID == reelID,
                      self.playbackLoadID == loadID
                else {
                    return
                }

                self.reelPlaybackProgress = progress
            }

            seekAndPlay(
                for: reelID,
                from: pendingPlaybackStartTimeMillis
            )

            playbackLoadingReelID = nil

        } catch is CancellationError {
            guard playbackLoadID == loadID,
                  activePlaybackReelID == reelID else {
                return
            }

            stopPlayback()

        } catch {
            guard playbackLoadID == loadID,
                  activePlaybackReelID == reelID else {
                return
            }

            playbackService.stop()
            playbackLoadingReelID = nil
            playbackFailedReelID = reelID
        }
    }

    private func seekAndPlay(
        for reelID: Int64,
        from startTimeMillis: Int64
    ) {
        let safeStartTimeMillis = max(
            startTimeMillis,
            0
        )

        let targetSeconds = TimeInterval(
            safeStartTimeMillis
        ) / 1_000
        let seekID = UUID()
        playbackSeekID = seekID

        if let duration = playbackService.player.currentItem?
            .duration.seconds,
           duration.isFinite,
           duration > 0 {
            reelPlaybackProgress = min(
                max(targetSeconds / duration, 0),
                1
            )
        }

        playbackService.seek(
            to: targetSeconds
        ) { [weak self] finished in
            Task { @MainActor [weak self] in
                guard let self,
                      self.playbackSeekID == seekID,
                      self.activePlaybackReelID == reelID,
                      self.pendingPlaybackStartTimeMillis
                        == safeStartTimeMillis
                else {
                    return
                }

                self.playbackSeekID = nil
                guard finished else {
                    self.playbackService.stop()
                    self.playbackLoadingReelID = nil
                    self.playbackFailedReelID = reelID
                    return
                }

                self.playbackService.play()
            }
        }
    }

    func pausePlayback() {
        playbackSeekID = nil
        guard activePlaybackReelID != nil,
              playbackLoadingReelID == nil,
              playbackFailedReelID == nil else {
            return
        }

        playbackService.pause()
    }

    func stopPlayback() {
        playbackLoadID = nil
        playbackSeekID = nil
        playbackService.stop()

        activePlaybackReelID = nil
        reelPlaybackProgress = 0
        playbackLoadingReelID = nil
        playbackFailedReelID = nil
        pendingPlaybackStartTimeMillis = 0
    }

    func retryInitialReels() async {
        reelState = .idle
        await loadInitialReels()
    }

    func isUpdatingLike(for reelID: Int64) -> Bool {
        likeUpdatingReelIDs.contains(reelID)
    }

    func isUpdatingSave(for reelID: Int64) -> Bool {
        saveUpdatingReelIDs.contains(reelID)
    }

    func toggleLike(for reelID: Int64) async {
        guard let reel = reel(withID: reelID) else {
            return
        }

        await setLike(
            for: reel,
            isLiked: !reel.isLikedByViewer
        )
    }

    /// 서버가 확정한 저장 상태를 반환한다.
    /// `nil`은 이미 요청 중이거나, 요청이 취소·실패한 경우다.
    func toggleSaved(for reelID: Int64) async -> Bool? {
        guard let reel = reel(withID: reelID) else {
            return nil
        }

        return await setSaved(
            for: reel,
            isSaved: !reel.isSavedByViewer
        )
    }

    func retryLastInteraction() async {
        guard let failedInteraction else {
            return
        }

        switch failedInteraction {
        case let .like(logID, isLiked):
            guard let reel = reel(withID: logID) else {
                return
            }
            await setLike(for: reel, isLiked: isLiked)

        case let .save(logID, isSaved):
            guard let reel = reel(withID: logID) else {
                return
            }
            _ = await setSaved(for: reel, isSaved: isSaved)
        }
    }

    func dismissInteractionError() {
        interactionError = nil
        failedInteraction = nil
    }

    func adjustCommentCount(
        for reelID: Int64,
        by delta: Int64
    ) {
        replaceReel(withID: reelID) { reel in
            reel.replacingCommentCount(
                max(0, reel.commentCount + delta)
            )
        }
    }

    // 실제 새로고침 함수
    private var isRefreshingHome = false

    func refreshHome(tourismPolicy: TourismFetchPolicy = .cached) async {
        guard !isRefreshingHome,
              tourismState != .loading,
              reelState != .loading
        else {
            return
        }

        isRefreshingHome = true
        defer { isRefreshingHome = false }

        async let tourism: Void = refreshTourisms(policy: tourismPolicy)
        async let reels: Void = refreshReels()

        _ = await (tourism, reels)
    }

    func playbackProgress(
        for reelID: Int64
    ) -> Double {
        guard activePlaybackReelID == reelID,
              playbackFailedReelID != reelID
        else {
            return 0
        }

        return reelPlaybackProgress
    }

    func isPlaying(reelID: Int64) -> Bool {
        guard activePlaybackReelID == reelID,
              playbackFailedReelID != reelID,
              playbackLoadingReelID == nil else {
            return false
        }

        return playbackService.player.timeControlStatus == .playing
    }

    func togglePlayback(for reelID: Int64) async {
        guard activePlaybackReelID == reelID,
              playbackFailedReelID != reelID else {
            await activatePlayback(for: reelID)
            return
        }

        if playbackService.player.timeControlStatus == .playing {
            playbackService.pause()
        } else {
            playbackService.play()
        }
    }

    func seekPlayback(to progress: Double, for reelID: Int64) {
        guard activePlaybackReelID == reelID,
              playbackFailedReelID != reelID else {
            return
        }

        guard let duration = playbackService.player.currentItem?.duration.seconds,
              duration.isFinite,
              duration > 0 else {
            return
        }

        let safeProgress = min(max(progress, 0), 1)
        let targetSeconds = duration * safeProgress

        // 사용자가 재생 바를 옮겼다면 이전 자동 이동의 취소 응답은 오류가 아니다.
        playbackSeekID = nil
        playbackService.seek(to: targetSeconds)
        reelPlaybackProgress = safeProgress
    }

    // API 요청 + Domain Model을 ViewData로 변환
    private func fetchTourismCards(policy: TourismFetchPolicy = .cached) async throws
        -> [HomeTourismCardViewData] {
        var cards: [HomeTourismCardViewData] = []
        var cursor: String?
        var seenCursors = Set<String>()
        var seenIDs = Set<Int64>()
        var firstFailure: Error?

        // 필터링 후 첫 페이지가 비어도 다음 페이지를 확인하되 요청량은 30개 후보로 제한한다.
        for _ in 0..<3 {
            try Task.checkCancellation()
            let page: TourismPage
            do {
                page = try await tourismRepository.fetchTourisms(category: .events, cursor: cursor, size: 10, policy: policy)
            } catch {
                try Task.checkCancellation()
                if cards.isEmpty || TourismErrorPolicy.presentation(for: error).recoveryAction == .signIn {
                    throw error
                }
                break
            }
            let candidates = page.tourisms.filter { seenIDs.insert($0.id).inserted }
            let results = await fetchPortraitImages(for: candidates, policy: policy)
            for (tourism, result) in zip(candidates, results) {
                try Task.checkCancellation()
                switch result {
                case .success(let image):
                    if let image {
                        cards.append(makeCardViewData(from: tourism, poster: image))
                    }
                case .failure(let error):
                    if error is CancellationError || TourismErrorPolicy.presentation(for: error).recoveryAction == .signIn {
                        throw error
                    }
                    firstFailure = firstFailure ?? error
                }
            }
            if cards.count >= 10 { break }
            guard page.hasNext, let next = page.nextCursor, seenCursors.insert(next).inserted else { break }
            cursor = next
        }
        // 일시적 조회 실패를 '세로 이미지 없음'으로 오인하지 않도록 재시도 상태를 남긴다.
        if cards.isEmpty, let firstFailure { throw firstFailure }
        return Array(cards.prefix(10))
    }

    private func fetchPortraitImages(for tourisms: [Tourism], policy: TourismFetchPolicy) async -> [Result<TourismPortraitImage?, Error>] {
        let repository = tourismRepository
        return await withTaskGroup(of: (Int, Result<TourismPortraitImage?, Error>).self) { group in
            var results = Array<Result<TourismPortraitImage?, Error>>(
                repeating: .success(nil), count: tourisms.count
            )
            var nextIndex = 0
            // 상세와 이미지 요청을 한꺼번에 쏟지 않으면서 서버 목록 순서를 보존한다.
            func enqueue(_ index: Int) {
                let id = tourisms[index].id
                group.addTask {
                    do {
                        let image = try await repository.fetchPortraitImage(tourismID: id, policy: policy)
                        return (index, .success(image))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            while nextIndex < min(3, tourisms.count) {
                enqueue(nextIndex)
                nextIndex += 1
            }
            for await (index, result) in group {
                results[index] = result
                if nextIndex < tourisms.count, !Task.isCancelled {
                    enqueue(nextIndex)
                    nextIndex += 1
                }
            }
            return results
        }
    }

    private func fetchReelViewData() async throws
        -> [HomeReelViewData] {
        let page = try await logReelRepository.fetchReels(
            cursor: nil,
            size: 20
        )

        return page.reels.map { reel in
            makeReelViewData(from: reel)
        }
    }

    // 내부 새로고침 함수
    private func refreshTourisms(policy: TourismFetchPolicy) async {
        guard policy == .reload || !hasFreshTourismCards else { return }
        let previousState = tourismState

        do {
            let cards = try await fetchTourismCards(policy: policy)

            guard !Task.isCancelled else {
                return
            }

            tourismState = cards.isEmpty
                ? .empty
                : .content(cards)
            tourismsLoadedAt = now()

        } catch is CancellationError {
            return

        } catch {
            guard case .content(_) = previousState else {
                tourismState = .failed(
                    TourismErrorPolicy.presentation(for: error)
                )
                return
            }

            // 기존 카드가 보이는 중이었다면,
            // 새로고침 실패로 화면을 실패 화면으로 바꾸지 않는다.
        }
    }

    private func refreshReels() async {
        let previousState = reelState

        do {
            let reels = try await fetchReelViewData()

            guard !Task.isCancelled else {
                return
            }

            reelState = reels.isEmpty
                ? .empty
                : .content(reels)

        } catch is CancellationError {
            return

        } catch {
            guard case .content(_) = previousState else {
                reelState = .failed(
                    HomeReelErrorPolicy.presentation(for: error)
                )
                return
            }

            // 기존 릴스가 있다면 그대로 유지한다.
        }
    }

    private func setLike(
        for reel: HomeReelViewData,
        isLiked: Bool
    ) async {
        guard !likeUpdatingReelIDs.contains(reel.id) else {
            return
        }

        likeUpdatingReelIDs.insert(reel.id)
        interactionError = nil

        defer {
            likeUpdatingReelIDs.remove(reel.id)
        }

        do {
            let result = try await logInteractionRepository.setLike(
                logID: reel.id,
                isLiked: isLiked
            )

            guard !Task.isCancelled else {
                return
            }

            replaceReel(withID: reel.id) { current in
                let countChange: Int64
                if current.isLikedByViewer == result.isLiked {
                    countChange = 0
                } else {
                    countChange = result.isLiked ? 1 : -1
                }

                return current.replacingLike(
                    isLikedByViewer: result.isLiked,
                    likeCount: max(0, current.likeCount + countChange)
                )
            }
            failedInteraction = nil

        } catch is CancellationError {
            return

        } catch {
            guard !Task.isCancelled else {
                return
            }

            failedInteraction = .like(
                logID: reel.id,
                isLiked: isLiked
            )
            interactionError = LogInteractionErrorPolicy.presentation(
                for: error,
                actionName: isLiked ? "좋아요" : "좋아요 취소"
            )
        }
    }

    private func setSaved(
        for reel: HomeReelViewData,
        isSaved: Bool
    ) async -> Bool? {
        guard !saveUpdatingReelIDs.contains(reel.id) else {
            return nil
        }

        saveUpdatingReelIDs.insert(reel.id)
        interactionError = nil

        defer {
            saveUpdatingReelIDs.remove(reel.id)
        }

        do {
            let result = try await logInteractionRepository.setSaved(
                logID: reel.id,
                isSaved: isSaved
            )

            guard !Task.isCancelled else {
                return nil
            }

            replaceReel(withID: reel.id) { current in
                current.replacingSaved(
                    isSavedByViewer: result.isSaved
                )
            }
            failedInteraction = nil
            return result.isSaved

        } catch is CancellationError {
            return nil

        } catch {
            guard !Task.isCancelled else {
                return nil
            }

            failedInteraction = .save(
                logID: reel.id,
                isSaved: isSaved
            )
            interactionError = LogInteractionErrorPolicy.presentation(
                for: error,
                actionName: isSaved ? "저장" : "저장 취소"
            )
            return nil
        }
    }

    private func reel(
        withID reelID: Int64
    ) -> HomeReelViewData? {
        guard case let .content(reels) = reelState else {
            return nil
        }

        return reels.first { $0.id == reelID }
    }

    private func replaceReel(
        withID reelID: Int64,
        transform: (HomeReelViewData) -> HomeReelViewData
    ) {
        guard case let .content(reels) = reelState else {
            return
        }

        reelState = .content(
            reels.map { reel in
                reel.id == reelID ? transform(reel) : reel
            }
        )
    }

    private func makeReelViewData(
        from reel: LogReel
    ) -> HomeReelViewData {
        HomeReelViewData(
            id: reel.id,
            authorID: reel.author.id,
            authorName: reel.author.nickname,
            authorProfileImageURL: reel.author.profileImageURL,
            caption: reel.caption,
            address: reel.address,
            thumbnailURL: reel.thumbnailURL,
            playbackURL: reel.playbackURL,
            publishedAt: reel.publishedAt,
            viewCount: reel.viewCount,
            likeCount: reel.likeCount,
            commentCount: reel.commentCount,
            isLikedByViewer: reel.isLikedByViewer,
            isSavedByViewer: reel.isSavedByViewer,
            clips: reel.clips.map { clip in
                HomeReelClipViewData(
                    id: clip.id,
                    displayOrder: clip.displayOrder,
                    startTimeMillis: clip.startTimeMillis,
                    endTimeMillis: clip.endTimeMillis,
                    placeName: clip.location.name,
                    address: clip.location.address,
                    latitude: clip.location.latitude,
                    longitude: clip.location.longitude,
                    thumbnailURL: clip.thumbnailURL
                )
            }
        )
    }

    private func makeCardViewData(from tourism: Tourism, poster: TourismPortraitImage) -> HomeTourismCardViewData {
        HomeTourismCardViewData(
            id: tourism.id,
            title: tourism.name,
            locationText: tourism.region ?? tourism.address ?? "지역 정보 없음",
            periodText: HomeTourismPeriodFormatter.string(
                startDate: tourism.startDate,
                endDate: tourism.endDate
            ),
            dDayText: dDayText(startDate: tourism.startDate, endDate: tourism.endDate),
            poster: poster
        )
    }

    private func dDayText(startDate: Date?, endDate: Date?) -> String? {
        let status = TourismScheduleStatusCalculator.make(startDate: startDate, endDate: endDate)

        switch status {
        case .ongoing:
            return "진행 중"

        case let .upcoming(daysRemaining):
            return "D-\(daysRemaining)"

        case .ended, .unavailable:
            return nil
        }
    }


}
