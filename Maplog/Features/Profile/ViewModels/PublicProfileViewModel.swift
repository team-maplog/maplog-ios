import Foundation

enum PublicProfileScreenState: Equatable {
    case idle
    case loading
    case content
    case failed(ErrorPresentation)
}

@MainActor
final class PublicProfileViewModel: ObservableObject {
    @Published private(set) var state: PublicProfileScreenState = .idle
    @Published private(set) var isFollowing = false
    @Published private(set) var isOwnProfile = false
    @Published private(set) var avatarImageData: Data?
    @Published private(set) var isUpdatingFollowState = false
    @Published private(set) var actionError: ErrorPresentation?

    let user: FollowUser

    private let followRepository: any FollowRepository
    private let profileRepository: any ProfileRepository

    init(
        user: FollowUser,
        followRepository: any FollowRepository,
        profileRepository: any ProfileRepository
    ) {
        self.user = user
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
        guard state != .loading else {
            return
        }

        state = .loading
        actionError = nil

        do {
            let myProfile = try await profileRepository.fetchMyProfile()
            let followsUser: Bool

            if myProfile.id == user.id {
                followsUser = false
                isOwnProfile = true
            } else {
                followsUser = try await followRepository.isFollowing(
                    userID: user.id
                )
                isOwnProfile = false
            }

            guard !Task.isCancelled else {
                return
            }

            isFollowing = followsUser
            state = .content
            await loadAvatarImage()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else {
                return
            }

            state = .failed(
                FollowErrorPolicy.presentation(
                    for: error,
                    actionName: "프로필 불러오기"
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

    func toggleFollow() async {
        guard state == .content,
              !isOwnProfile,
              !isUpdatingFollowState
        else {
            return
        }

        let requestedState = !isFollowing
        isUpdatingFollowState = true
        actionError = nil

        defer {
            isUpdatingFollowState = false
        }

        do {
            let state = try await followRepository.setFollowing(
                userID: user.id,
                isFollowing: requestedState
            )

            guard !Task.isCancelled else {
                return
            }

            isFollowing = state.isFollowing
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else {
                return
            }

            actionError = FollowErrorPolicy.presentation(
                for: error,
                actionName: requestedState ? "팔로우" : "팔로우 취소"
            )
        }
    }

    func dismissActionError() {
        actionError = nil
    }

    private func loadAvatarImage() async {
        guard let url = user.profileImageURL else {
            return
        }

        do {
            let data = try await profileRepository.fetchImageData(from: url)

            guard !Task.isCancelled else {
                return
            }

            avatarImageData = data
        } catch {
            // 공개 프로필 사진은 보조 정보이므로 실패해도 이니셜 아바타를 사용합니다.
            return
        }
    }
}
