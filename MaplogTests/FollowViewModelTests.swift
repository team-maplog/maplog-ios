import Foundation
import XCTest
@testable import Maplog

@MainActor
final class FollowViewModelTests: XCTestCase {
    func testFollowingListAppendsNextPage() async {
        let firstUser = makeUser(nickname: "성수여행자")
        let secondUser = makeUser(nickname: "연남산책자")
        let followRepository = FollowRepositoryStub(
            pages: [
                FollowUserPage(
                    users: [firstUser],
                    hasNext: true,
                    nextCursor: "following-next"
                ),
                FollowUserPage(
                    users: [secondUser],
                    hasNext: false,
                    nextCursor: nil
                )
            ]
        )
        let viewModel = FollowUserListViewModel(
            kind: .following,
            followRepository: followRepository,
            profileRepository: FollowProfileRepositoryStub()
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.state, .content)
        XCTAssertEqual(viewModel.users.map(\.id), [firstUser.id])
        XCTAssertTrue(viewModel.hasNextPage)
        XCTAssertEqual(followRepository.requestedCursors, [nil])

        await viewModel.loadNextPage()

        XCTAssertEqual(
            viewModel.users.map(\.id),
            [firstUser.id, secondUser.id]
        )
        XCTAssertFalse(viewModel.hasNextPage)
        XCTAssertEqual(
            followRepository.requestedCursors,
            [nil, "following-next"]
        )
    }

    func testPublicProfileToggleFollowUsesReturnedState() async {
        let user = makeUser(nickname: "서울여행자")
        let followRepository = FollowRepositoryStub(
            isFollowing: false
        )
        let viewModel = PublicProfileViewModel(
            user: user,
            followRepository: followRepository,
            profileRepository: FollowProfileRepositoryStub()
        )

        await viewModel.loadIfNeeded()
        await viewModel.toggleFollow()

        XCTAssertEqual(viewModel.state, .content)
        XCTAssertTrue(viewModel.isFollowing)
        XCTAssertEqual(
            followRepository.followRequests,
            [FollowRepositoryStub.FollowRequest(
                userID: user.id,
                isFollowing: true
            )]
        )
    }

    func testUnfollowingRemovesUserFromFollowingList() async {
        let user = makeUser(nickname: "제주여행자")
        let viewModel = FollowUserListViewModel(
            kind: .following,
            followRepository: FollowRepositoryStub(
                pages: [
                    FollowUserPage(
                        users: [user],
                        hasNext: false,
                        nextCursor: nil
                    )
                ]
            ),
            profileRepository: FollowProfileRepositoryStub()
        )

        await viewModel.loadIfNeeded()
        viewModel.apply(
            FollowState(userID: user.id, isFollowing: false)
        )

        XCTAssertTrue(viewModel.users.isEmpty)
        XCTAssertEqual(viewModel.state, .empty)
    }

    private func makeUser(
        nickname: String
    ) -> FollowUser {
        FollowUser(
            id: UUID(),
            nickname: nickname,
            profileImageURL: nil
        )
    }
}

private final class FollowRepositoryStub: FollowRepository {
    struct FollowRequest: Equatable {
        let userID: UUID
        let isFollowing: Bool
    }

    private var pages: [FollowUserPage]
    private var currentFollowState: Bool
    private(set) var requestedCursors: [String?] = []
    private(set) var followRequests: [FollowRequest] = []

    init(
        pages: [FollowUserPage] = [],
        isFollowing: Bool = false
    ) {
        self.pages = pages
        self.currentFollowState = isFollowing
    }

    func fetchUsers(
        kind: FollowListKind,
        cursor: String?,
        size: Int
    ) async throws -> FollowUserPage {
        requestedCursors.append(cursor)

        guard !pages.isEmpty else {
            return FollowUserPage(
                users: [],
                hasNext: false,
                nextCursor: nil
            )
        }

        return pages.removeFirst()
    }

    func isFollowing(
        userID: UUID
    ) async throws -> Bool {
        currentFollowState
    }

    func setFollowing(
        userID: UUID,
        isFollowing: Bool
    ) async throws -> FollowState {
        followRequests.append(
            FollowRequest(
                userID: userID,
                isFollowing: isFollowing
            )
        )
        currentFollowState = isFollowing

        return FollowState(
            userID: userID,
            isFollowing: isFollowing
        )
    }
}

private final class FollowProfileRepositoryStub: ProfileRepository {
    func fetchMyProfile() async throws -> MyProfile {
        MyProfile(
            id: UUID(),
            nickname: "나",
            profileImageURL: nil,
            bio: "",
            followerCount: 0,
            followingCount: 0,
            logCount: 0
        )
    }

    func fetchMyLogs(
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPage {
        ProfileLogPage(logs: [], hasNext: false, nextCursor: nil)
    }

    func updateMyProfile(
        _ update: ProfileUpdate
    ) async throws -> MyProfile {
        try await fetchMyProfile()
    }

    func deleteMyProfile() async throws {}

    func fetchImageData(
        from url: URL
    ) async throws -> Data {
        Data()
    }
}
