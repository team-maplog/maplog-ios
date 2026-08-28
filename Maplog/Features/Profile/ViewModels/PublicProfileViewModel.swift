import Foundation

enum PublicProfileScreenState: Equatable {
    case idle
    case loading
    case content
    case failed(ErrorPresentation)
}

/// 공개 프로필 헤더를 화면에 그리기 위한 데이터입니다.
/// API 응답 모델을 View가 직접 알지 않도록, 숫자·날짜 표현은 여기서 정리합니다.
struct PublicProfileHeaderViewData: Equatable {
    let id: UUID
    let nickname: String
    let bio: String
    let followerCountText: String
    let followingCountText: String
    let logCountText: String
    let joinedAtText: String
}

@MainActor
final class PublicProfileViewModel: ObservableObject {
    @Published private(set) var state: PublicProfileScreenState = .idle
    @Published private(set) var profile: PublicProfileHeaderViewData?
    @Published private(set) var logs: [ProfileLogCardViewData] = []
    @Published private(set) var avatarImageData: Data?
    @Published private(set) var thumbnailDataByLogID: [Int64: Data] = [:]
    @Published private(set) var thumbnailLoadingIDs = Set<Int64>()
    @Published private(set) var isFollowing = false
    @Published private(set) var isOwnProfile = false
    @Published private(set) var isUpdatingFollowState = false
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var hasNextPage = false
    @Published private(set) var nextPageError: ErrorPresentation?
    @Published private(set) var actionError: ErrorPresentation?

    private let routeUser: FollowUser
    private let followRepository: any FollowRepository
    private let profileRepository: any ProfileRepository
    private let pageSize = 20
    private var loadedProfile: PublicProfile?
    private var nextCursor: String?

    init(
        user: FollowUser,
        followRepository: any FollowRepository,
        profileRepository: any ProfileRepository
    ) {
        routeUser = user
        self.followRepository = followRepository
        self.profileRepository = profileRepository
    }

    var nickname: String {
        profile?.nickname ?? routeUser.nickname
    }

    func loadIfNeeded() async {
        guard state == .idle else {
            return
        }

        await reload()
    }

    func reload() async {
        guard state != .loading else {
            return
        }

        let preservesVisibleContent = state == .content

        if preservesVisibleContent {
            nextPageError = nil
        } else {
            state = .loading
            profile = nil
            logs = []
            avatarImageData = nil
            thumbnailDataByLogID = [:]
            thumbnailLoadingIDs = []
            isFollowing = false
            isOwnProfile = false
            hasNextPage = false
            nextCursor = nil
            nextPageError = nil
        }

        actionError = nil

        do {
            // 공개 헤더·로그 첫 페이지·내 사용자 ID는 서로 독립적이라 병렬로 가져옵니다.
            async let fetchedProfile = profileRepository.fetchPublicProfile(
                nickname: routeUser.nickname
            )
            async let firstPage = profileRepository.fetchPublicProfileLogs(
                nickname: routeUser.nickname,
                cursor: nil,
                size: pageSize
            )
            async let fetchedViewerProfile = profileRepository.fetchMyProfile()

            let (publicProfile, page, viewerProfile) = try await (
                fetchedProfile,
                firstPage,
                fetchedViewerProfile
            )

            guard !Task.isCancelled else {
                restoreStateAfterCancellation(
                    preservesVisibleContent: preservesVisibleContent
                )
                return
            }

            loadedProfile = publicProfile
            profile = makeHeaderViewData(from: publicProfile)
            isFollowing = publicProfile.isFollowedByViewer
            isOwnProfile = publicProfile.id == viewerProfile.id
            logs = page.logs.map(makeLogCardViewData)
            nextCursor = page.nextCursor
            hasNextPage = page.hasNext
            state = .content

            loadImages(
                for: publicProfile,
                logs: page.logs
            )
        } catch is CancellationError {
            restoreStateAfterCancellation(
                preservesVisibleContent: preservesVisibleContent
            )
        } catch {
            guard !Task.isCancelled else {
                restoreStateAfterCancellation(
                    preservesVisibleContent: preservesVisibleContent
                )
                return
            }

            if !preservesVisibleContent {
                state = .failed(
                    PublicProfileErrorPolicy.initialPresentation(for: error)
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
            let page = try await profileRepository.fetchPublicProfileLogs(
                nickname: routeUser.nickname,
                cursor: nextCursor,
                size: pageSize
            )

            guard !Task.isCancelled else {
                return
            }

            logs.append(contentsOf: page.logs.map(makeLogCardViewData))
            self.nextCursor = page.nextCursor
            hasNextPage = page.hasNext
            loadThumbnails(for: page.logs)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else {
                return
            }

            if PublicProfileErrorPolicy.isCursorInvalid(error) {
                await reload()
                return
            }

            // 이미 보여 준 첫 페이지는 지우지 않고, 하단에서만 재시도하게 합니다.
            nextPageError = PublicProfileErrorPolicy.nextPagePresentation(
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

    @discardableResult
    func toggleFollow() async -> FollowState? {
        guard state == .content,
              !isOwnProfile,
              !isUpdatingFollowState,
              let loadedProfile
        else {
            return nil
        }

        let requestedState = !isFollowing
        isUpdatingFollowState = true
        actionError = nil

        defer {
            isUpdatingFollowState = false
        }

        do {
            let followState = try await followRepository.setFollowing(
                userID: loadedProfile.id,
                isFollowing: requestedState
            )

            guard !Task.isCancelled else {
                return nil
            }

            guard followState.userID == loadedProfile.id else {
                throw APIError.invalidResponse
            }

            let updatedProfile = loadedProfile.replacingFollowState(
                isFollowedByViewer: followState.isFollowing
            )
            self.loadedProfile = updatedProfile
            profile = makeHeaderViewData(from: updatedProfile)
            isFollowing = followState.isFollowing

            return followState
        } catch is CancellationError {
            return nil
        } catch {
            guard !Task.isCancelled else {
                return nil
            }

            actionError = FollowErrorPolicy.presentation(
                for: error,
                actionName: requestedState ? "팔로우" : "팔로우 취소"
            )
            return nil
        }
    }

    func dismissActionError() {
        actionError = nil
    }

    private func restoreStateAfterCancellation(
        preservesVisibleContent: Bool
    ) {
        guard !preservesVisibleContent else {
            return
        }

        state = .idle
    }

    private func makeHeaderViewData(
        from profile: PublicProfile
    ) -> PublicProfileHeaderViewData {
        PublicProfileHeaderViewData(
            id: profile.id,
            nickname: profile.nickname,
            bio: profile.bio,
            followerCountText: countText(profile.followerCount),
            followingCountText: countText(profile.followingCount),
            logCountText: countText(profile.logCount),
            joinedAtText: profile.createdAt.formatted(
                .dateTime.year().month()
            )
        )
    }

    private func makeLogCardViewData(
        from log: ProfileLog
    ) -> ProfileLogCardViewData {
        ProfileLogCardViewData(
            id: log.id,
            addressText: displayAddress(log.address),
            durationText: durationText(milliseconds: log.videoDurationMillis),
            viewCountText: countText(log.viewCount),
            createdAtText: log.createdAt.formatted(
                .dateTime.year().month().day()
            )
        )
    }

    private func loadImages(
        for profile: PublicProfile,
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

        loadThumbnails(for: logs)
    }

    private func loadAvatar(
        from url: URL,
        profileID: UUID
    ) async {
        do {
            let data = try await profileRepository.fetchImageData(from: url)

            guard !Task.isCancelled,
                  profile?.id == profileID
            else {
                return
            }

            avatarImageData = data
        } catch {
            // 프로필 이미지는 보조 정보이므로, 실패하면 이니셜 아바타를 유지합니다.
        }
    }

    private func loadThumbnails(
        for logs: [ProfileLog]
    ) {
        for log in logs {
            loadThumbnail(for: log)
        }
    }

    private func loadThumbnail(
        for log: ProfileLog
    ) {
        guard let url = log.thumbnailURL,
              thumbnailDataByLogID[log.id] == nil,
              !thumbnailLoadingIDs.contains(log.id)
        else {
            return
        }

        thumbnailLoadingIDs.insert(log.id)

        Task { [weak self] in
            guard let self else {
                return
            }

            defer {
                thumbnailLoadingIDs.remove(log.id)
            }

            do {
                let data = try await profileRepository.fetchImageData(from: url)

                guard !Task.isCancelled else {
                    return
                }

                thumbnailDataByLogID[log.id] = data
            } catch {
                // 목록 이미지는 보조 UI이므로, 실패해도 빈 카드로 유지합니다.
            }
        }
    }

    private func countText(
        _ count: Int64
    ) -> String {
        count.formatted(.number.notation(.compactName))
    }

    private func durationText(
        milliseconds: Int64
    ) -> String {
        let totalSeconds = max(0, milliseconds / 1_000)
        return String(
            format: "%d:%02d",
            totalSeconds / 60,
            totalSeconds % 60
        )
    }

    private func displayAddress(
        _ address: String
    ) -> String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
