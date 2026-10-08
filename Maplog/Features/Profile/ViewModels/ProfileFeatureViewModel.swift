import Foundation

enum ProfileScreenState: Equatable {
    case idle
    case initialLoading
    case content
    case failed(ErrorPresentation)
}

enum ProfileLogListState: Equatable {
    case idle
    case initialLoading
    case content
    case failed(ErrorPresentation)
}

struct ProfileHeaderViewData: Equatable {
    let id: UUID
    let nickname: String
    let bio: String
    let followerCountText: String
    let followingCountText: String
    let logCountText: String
}

struct ProfileLogCardViewData: Identifiable, Equatable {
    let id: Int64
    let addressText: String
    let durationText: String
    let viewCountText: String
    let createdAtText: String
}

@MainActor
final class ProfileTabViewModel: ObservableObject {
    @Published private(set) var state: ProfileScreenState = .idle
    @Published private(set) var profile: ProfileHeaderViewData?
    @Published private(set) var logs: [ProfileLogCardViewData] = []
    @Published private(set) var savedLogsState: ProfileLogListState = .idle
    @Published private(set) var savedLogs: [ProfileLogCardViewData] = []
    @Published private(set) var avatarImageData: Data?
    @Published private(set) var thumbnailDataByLogID: [Int64: Data] = [:]
    @Published private(set) var thumbnailLoadingIDs: Set<Int64> = []
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var nextPageError: ErrorPresentation?
    @Published private(set) var hasNextPage = false
    @Published private(set) var isLoadingNextSavedLogsPage = false
    @Published private(set) var nextSavedLogsPageError: ErrorPresentation?
    @Published private(set) var hasNextSavedLogsPage = false

    private let profileRepository: any ProfileRepository
    private let logReelRepository: any LogReelRepository
    private let pageSize = 20
    private var nextCursor: String?
    private var nextSavedLogsCursor: String?
    private var profileHeaderRequestID = UUID()
    private var needsProfileHeaderRefresh = false
    private var isRefreshingProfileHeader = false

    init(
        profileRepository: any ProfileRepository,
        logReelRepository: any LogReelRepository
    ) {
        self.profileRepository = profileRepository
        self.logReelRepository = logReelRepository
    }

    func loadIfNeeded() async {
        guard state == .idle else {
            return
        }

        await reload()
    }

    func refreshAfterFollowChange() async {
        // 진행 중인 이전 프로필 조회가 팔로우 변경 이전 값을 적용하지 못하게 한다.
        profileHeaderRequestID = UUID()
        needsProfileHeaderRefresh = true
        await refreshProfileHeaderIfNeeded()
    }

    func refreshProfileHeaderIfNeeded() async {
        guard state == .content, !isRefreshingProfileHeader else { return }
        isRefreshingProfileHeader = true
        defer { isRefreshingProfileHeader = false }

        while needsProfileHeaderRefresh {
            needsProfileHeaderRefresh = false
            let requestID = UUID()
            profileHeaderRequestID = requestID
            do {
                try Task.checkCancellation()
                let latest = try await profileRepository.fetchMyProfile()
                try Task.checkCancellation()
                guard profileHeaderRequestID == requestID else { continue }
                profile = makeProfileViewData(from: latest)
            } catch {
                guard profileHeaderRequestID == requestID else { continue }
                // 기존 헤더·로그는 유지하고 다음 프로필 진입에서 다시 조회한다.
                needsProfileHeaderRefresh = true
                return
            }
        }
    }

    func reload() async {
        guard state != .initialLoading else {
            return
        }

        let preservesVisibleContent = state == .content
        let headerRequestID = UUID()
        profileHeaderRequestID = headerRequestID
        if isRefreshingProfileHeader { needsProfileHeaderRefresh = true }

        if preservesVisibleContent {
            // pull-to-refresh에서는 기존 프로필을 지우지 않는다.
            // SwiftUI의 refreshable 인디케이터가 진행 상태를 따로 보여 준다.
            nextPageError = nil
        } else {
            state = .initialLoading
            profile = nil
            logs = []
            avatarImageData = nil
            thumbnailDataByLogID = [:]
            thumbnailLoadingIDs = []
            nextPageError = nil
            nextCursor = nil
            hasNextPage = false
            isLoadingNextPage = false
        }

        do {
            async let fetchedProfile = profileRepository.fetchMyProfile()
            async let firstPage = profileRepository.fetchMyLogs(
                cursor: nil,
                size: pageSize
            )

            let (myProfile, page) = try await (
                fetchedProfile,
                firstPage
            )

            guard !Task.isCancelled else {
                restoreProfileStateAfterCancellation(
                    preservesVisibleContent: preservesVisibleContent
                )
                return
            }

            if profile == nil || profileHeaderRequestID == headerRequestID {
                profile = makeProfileViewData(from: myProfile)
            }
            if profileHeaderRequestID == headerRequestID {
                needsProfileHeaderRefresh = false
            }

            let profileLogs = page.logs.map(
                makeLogCardViewData
            )

            logs = profileLogs
            nextCursor = page.nextCursor
            hasNextPage = page.hasNext
            state = .content

            loadImages(
                for: myProfile,
                logs: page.logs
            )
            await refreshProfileHeaderIfNeeded()
        } catch is CancellationError {
            restoreProfileStateAfterCancellation(
                preservesVisibleContent: preservesVisibleContent
            )
            return
        } catch {
            guard !Task.isCancelled else {
                restoreProfileStateAfterCancellation(
                    preservesVisibleContent: preservesVisibleContent
                )
                return
            }

            if !preservesVisibleContent {
                state = .failed(
                    ProfileErrorPolicy.presentation(
                        for: error
                    )
                )
            }
        }
    }

    func retryInitialLoad() async {
        guard case .failed = state else {
            return
        }

        state = .idle
        await reload()
    }

    func loadNextPage() async {
        guard state == .content,
              hasNextPage,
              !isLoadingNextPage,
              let nextCursor
        else {
            return
        }

        isLoadingNextPage = true
        nextPageError = nil

        defer {
            isLoadingNextPage = false
        }

        do {
            let page = try await profileRepository.fetchMyLogs(
                cursor: nextCursor,
                size: pageSize
            )

            guard !Task.isCancelled else {
                return
            }

            let newLogs = page.logs.map(
                makeLogCardViewData
            )

            logs.append(contentsOf: newLogs)
            self.nextCursor = page.nextCursor
            hasNextPage = page.hasNext

            loadThumbnails(
                for: page.logs
            )
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else {
                return
            }

            if ProfileErrorPolicy.isCursorInvalid(error) {
                await reload()
                return
            }

            nextPageError = ProfileErrorPolicy.presentation(
                for: error
            )
        }
    }

    func retryNextPage() async {
        guard nextPageError != nil else {
            return
        }

        await loadNextPage()
    }

    func loadSavedLogsIfNeeded() async {
        guard savedLogsState == .idle else {
            return
        }

        await reloadSavedLogs()
    }

    func reloadSavedLogs() async {
        guard savedLogsState != .initialLoading else {
            return
        }

        let preservesVisibleContent = savedLogsState == .content

        if preservesVisibleContent {
            // 저장 탭도 새로고침 중에는 기존 목록을 유지한다.
            nextSavedLogsPageError = nil
        } else {
            savedLogsState = .initialLoading
            savedLogs = []
            nextSavedLogsCursor = nil
            hasNextSavedLogsPage = false
            isLoadingNextSavedLogsPage = false
            nextSavedLogsPageError = nil
        }

        do {
            let page = try await logReelRepository.fetchSavedLogs(
                cursor: nil,
                size: pageSize
            )

            guard !Task.isCancelled else {
                restoreSavedLogsStateAfterCancellation(
                    preservesVisibleContent: preservesVisibleContent
                )
                return
            }

            savedLogs = page.reels.map(makeLogCardViewData)
            nextSavedLogsCursor = page.nextCursor
            hasNextSavedLogsPage = page.hasNext
            savedLogsState = .content

            loadThumbnails(for: page.reels)
        } catch is CancellationError {
            restoreSavedLogsStateAfterCancellation(
                preservesVisibleContent: preservesVisibleContent
            )
            return
        } catch {
            guard !Task.isCancelled else {
                restoreSavedLogsStateAfterCancellation(
                    preservesVisibleContent: preservesVisibleContent
                )
                return
            }

            if !preservesVisibleContent {
                savedLogsState = .failed(
                    ProfileErrorPolicy.presentation(for: error)
                )
            }
        }
    }

    func retryInitialSavedLogsLoad() async {
        guard case .failed = savedLogsState else {
            return
        }

        savedLogsState = .idle
        await reloadSavedLogs()
    }

    func loadNextSavedLogsPage() async {
        guard savedLogsState == .content,
              hasNextSavedLogsPage,
              !isLoadingNextSavedLogsPage,
              let nextSavedLogsCursor
        else {
            return
        }

        isLoadingNextSavedLogsPage = true
        nextSavedLogsPageError = nil

        defer {
            isLoadingNextSavedLogsPage = false
        }

        do {
            let page = try await logReelRepository.fetchSavedLogs(
                cursor: nextSavedLogsCursor,
                size: pageSize
            )

            guard !Task.isCancelled else {
                return
            }

            savedLogs.append(
                contentsOf: page.reels.map(makeLogCardViewData)
            )
            self.nextSavedLogsCursor = page.nextCursor
            hasNextSavedLogsPage = page.hasNext

            loadThumbnails(for: page.reels)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else {
                return
            }

            if ProfileErrorPolicy.isCursorInvalid(error) {
                await reloadSavedLogs()
                return
            }

            nextSavedLogsPageError = ProfileErrorPolicy.presentation(for: error)
        }
    }

    func retryNextSavedLogsPage() async {
        guard nextSavedLogsPageError != nil else {
            return
        }

        await loadNextSavedLogsPage()
    }

    func removeSavedLog(
        withID logID: Int64
    ) {
        savedLogs.removeAll { $0.id == logID }
    }

    func thumbnailData(
        for logID: Int64
    ) -> Data? {
        thumbnailDataByLogID[logID]
    }

    func isLoadingThumbnail(
        for logID: Int64
    ) -> Bool {
        thumbnailLoadingIDs.contains(logID)
    }

    private func restoreProfileStateAfterCancellation(
        preservesVisibleContent: Bool
    ) {
        guard !preservesVisibleContent else {
            return
        }

        // .task가 취소돼도 initialLoading에 남으면 다음 진입·새로고침이 막힌다.
        state = .idle
    }

    private func restoreSavedLogsStateAfterCancellation(
        preservesVisibleContent: Bool
    ) {
        guard !preservesVisibleContent else {
            return
        }

        savedLogsState = .idle
    }

    private func makeProfileViewData(
        from profile: MyProfile
    ) -> ProfileHeaderViewData {
        ProfileHeaderViewData(
            id: profile.id,
            nickname: profile.nickname,
            bio: profile.bio,
            followerCountText: countText(
                profile.followerCount
            ),
            followingCountText: countText(
                profile.followingCount
            ),
            logCountText: countText(
                profile.logCount
            )
        )
    }

    private func makeLogCardViewData(
        from log: ProfileLog
    ) -> ProfileLogCardViewData {
        ProfileLogCardViewData(
            id: log.id,
            addressText: displayAddress(
                log.address
            ),
            durationText: durationText(
                milliseconds: log.videoDurationMillis
            ),
            viewCountText: countText(
                log.viewCount
            ),
            createdAtText: createdAtText(
                from: log.createdAt
            )
        )
    }

    private func makeLogCardViewData(
        from log: LogReel
    ) -> ProfileLogCardViewData {
        let videoDurationMillis = log.clips.map(\.endTimeMillis).max() ?? 0

        return ProfileLogCardViewData(
            id: log.id,
            addressText: displayAddress(log.address),
            durationText: durationText(
                milliseconds: videoDurationMillis
            ),
            viewCountText: countText(log.viewCount),
            createdAtText: createdAtText(
                from: log.publishedAt
            )
        )
    }

    private func loadImages(
        for profile: MyProfile,
        logs: [ProfileLog]
    ) {
        if let profileImageURL = profile.profileImageURL {
            Task { [weak self] in
                await self?.loadAvatar(
                    from: profileImageURL,
                    profileID: profile.id
                )
            }
        }

        loadThumbnails(
            for: logs
        )
    }

    private func loadAvatar(
        from url: URL,
        profileID: UUID
    ) async {
        do {
            let data = try await profileRepository.fetchImageData(
                from: url
            )

            guard !Task.isCancelled,
                  profile?.id == profileID
            else {
                return
            }

            avatarImageData = data
        } catch {
            return
        }
    }

    private func loadThumbnails(
        for logs: [ProfileLog]
    ) {
        for log in logs {
            loadThumbnail(
                for: log.id,
                from: log.thumbnailURL
            )
        }
    }

    private func loadThumbnails(
        for logs: [LogReel]
    ) {
        for log in logs {
            loadThumbnail(
                for: log.id,
                from: log.thumbnailURL
            )
        }
    }

    private func loadThumbnail(
        for logID: Int64,
        from thumbnailURL: URL?
    ) {
        guard let thumbnailURL,
              thumbnailDataByLogID[logID] == nil,
              !thumbnailLoadingIDs.contains(logID)
        else {
            return
        }

        thumbnailLoadingIDs.insert(logID)

        Task { [weak self] in
            guard let self else {
                return
            }

            defer {
                self.thumbnailLoadingIDs.remove(logID)
            }

            do {
                let data = try await self.profileRepository
                    .fetchImageData(
                        from: thumbnailURL,
                        cacheKey: "profile-log-thumbnail-\(logID)",
                        targetSize: .listThumbnail
                    )

                guard !Task.isCancelled,
                      self.containsVisibleLog(withID: logID)
                else {
                    return
                }

                self.thumbnailDataByLogID[logID] = data
            } catch {
                return
            }
        }
    }

    private func containsVisibleLog(
        withID logID: Int64
    ) -> Bool {
        logs.contains(where: { $0.id == logID })
            || savedLogs.contains(where: { $0.id == logID })
    }

    private func displayAddress(
        _ address: String
    ) -> String {
        let trimmedAddress = address.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmedAddress.isEmpty
            ? "지역 정보 없음"
            : trimmedAddress
    }

    private func durationText(
        milliseconds: Int64
    ) -> String {
        let totalSeconds = max(milliseconds / 1_000, 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return String(
            format: "%d:%02d",
            minutes,
            seconds
        )
    }

    private func countText(
        _ count: Int64
    ) -> String {
        countFormatter.string(
            from: NSNumber(value: count)
        ) ?? "0"
    }

    private func createdAtText(
        from date: Date
    ) -> String {
        createdAtFormatter.string(
            from: date
        )
    }

    private let countFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private let createdAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy. MM. dd."
        return formatter
    }()
}
