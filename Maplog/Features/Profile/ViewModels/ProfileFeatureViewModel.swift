import Foundation

enum ProfileScreenState: Equatable {
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
    @Published private(set) var avatarImageData: Data?
    @Published private(set) var thumbnailDataByLogID: [Int64: Data] = [:]
    @Published private(set) var thumbnailLoadingIDs: Set<Int64> = []
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var nextPageError: ErrorPresentation?
    @Published private(set) var hasNextPage = false

    private let profileRepository: any ProfileRepository
    private let pageSize = 20
    private var nextCursor: String?

    init(
        profileRepository: any ProfileRepository
    ) {
        self.profileRepository = profileRepository
    }

    func loadIfNeeded() async {
        guard state == .idle else {
            return
        }

        await reload()
    }

    func reload() async {
        guard state != .initialLoading else {
            return
        }

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
                return
            }

            profile = makeProfileViewData(
                from: myProfile
            )

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
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else {
                return
            }

            state = .failed(
                ProfileErrorPolicy.presentation(
                    for: error
                )
            )
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
            guard let thumbnailURL = log.thumbnailURL,
                  thumbnailDataByLogID[log.id] == nil,
                  !thumbnailLoadingIDs.contains(log.id)
            else {
                continue
            }

            thumbnailLoadingIDs.insert(log.id)

            Task { [weak self] in
                guard let self else {
                    return
                }

                defer {
                    self.thumbnailLoadingIDs.remove(log.id)
                }

                do {
                    let data = try await self.profileRepository
                        .fetchImageData(from: thumbnailURL)

                    guard !Task.isCancelled,
                          self.logs.contains(where: { $0.id == log.id })
                    else {
                        return
                    }

                    self.thumbnailDataByLogID[log.id] = data
                } catch {
                    return
                }
            }
        }
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
