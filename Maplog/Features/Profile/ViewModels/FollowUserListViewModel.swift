import Foundation

enum FollowUserListScreenState: Equatable {
    case idle
    case initialLoading
    case content
    case empty
    case failed(ErrorPresentation)
}

@MainActor
final class FollowUserListViewModel: ObservableObject {
    @Published private(set) var state: FollowUserListScreenState = .idle
    @Published private(set) var users: [FollowUser] = []
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var nextPageError: ErrorPresentation?
    @Published private(set) var hasNextPage = false
    @Published private var profileImageDataByUserID: [UUID: Data] = [:]
    @Published private var profileImageLoadingUserIDs = Set<UUID>()

    private let kind: FollowListKind
    private let followRepository: any FollowRepository
    private let profileRepository: any ProfileRepository
    private let pageSize = 20
    private var nextCursor: String?

    init(
        kind: FollowListKind,
        followRepository: any FollowRepository,
        profileRepository: any ProfileRepository
    ) {
        self.kind = kind
        self.followRepository = followRepository
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
        users = []
        hasNextPage = false
        nextCursor = nil
        nextPageError = nil
        isLoadingNextPage = false
        profileImageDataByUserID = [:]
        profileImageLoadingUserIDs = []

        do {
            let page = try await followRepository.fetchUsers(
                kind: kind,
                cursor: nil,
                size: pageSize
            )

            guard !Task.isCancelled else {
                return
            }

            users = page.users
            hasNextPage = page.hasNext
            nextCursor = page.nextCursor
            state = page.users.isEmpty ? .empty : .content
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else {
                return
            }

            state = .failed(
                FollowErrorPolicy.presentation(
                    for: error,
                    actionName: "\(kind.title) 목록 불러오기"
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
            let page = try await followRepository.fetchUsers(
                kind: kind,
                cursor: nextCursor,
                size: pageSize
            )

            guard !Task.isCancelled else {
                return
            }

            users.append(contentsOf: page.users)
            self.nextCursor = page.nextCursor
            hasNextPage = page.hasNext
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else {
                return
            }

            if FollowErrorPolicy.isCursorInvalid(error) {
                await reload()
                return
            }

            nextPageError = FollowErrorPolicy.presentation(
                for: error,
                actionName: "\(kind.title) 더 불러오기"
            )
        }
    }

    func retryNextPage() async {
        guard nextPageError != nil else {
            return
        }

        await loadNextPage()
    }

    func apply(
        _ state: FollowState
    ) {
        guard kind == .following,
              !state.isFollowing
        else {
            return
        }

        users.removeAll { $0.id == state.userID }
        if users.isEmpty {
            self.state = .empty
        }
    }

    func profileImageData(
        for user: FollowUser
    ) -> Data? {
        profileImageDataByUserID[user.id]
    }

    func loadProfileImage(
        for user: FollowUser
    ) async {
        guard let url = user.profileImageURL,
              profileImageDataByUserID[user.id] == nil,
              !profileImageLoadingUserIDs.contains(user.id)
        else {
            return
        }

        profileImageLoadingUserIDs.insert(user.id)

        defer {
            profileImageLoadingUserIDs.remove(user.id)
        }

        do {
            let data = try await profileRepository.fetchImageData(
                from: url
            )

            guard !Task.isCancelled else {
                return
            }

            profileImageDataByUserID[user.id] = data
        } catch {
            // 이미지 한 장 실패는 목록 상태를 실패로 바꾸지 않고 기본 아바타를 유지합니다.
            return
        }
    }
}
