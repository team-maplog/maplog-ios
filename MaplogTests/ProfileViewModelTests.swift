import Foundation
import XCTest
@testable import Maplog

@MainActor
final class ProfileViewModelTests: XCTestCase {
    func testLoadThenLoadNextPageAppendsLogs() async {
        let repository = ProfileRepositoryStub(
            profile: MyProfile(
                id: UUID(),
                nickname: "채림",
                profileImageURL: nil,
                bio: "여행을 기록합니다.",
                followerCount: 12,
                followingCount: 8,
                logCount: 2
            ),
            pages: [
                ProfileLogPage(
                    logs: [
                        makeLog(id: 1, address: "서울 성수동")
                    ],
                    hasNext: true,
                    nextCursor: "next-page"
                ),
                ProfileLogPage(
                    logs: [
                        makeLog(id: 2, address: "서울 연남동")
                    ],
                    hasNext: false,
                    nextCursor: nil
                )
            ]
        )
        let viewModel = ProfileTabViewModel(profileRepository: repository)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.state, .content)
        XCTAssertEqual(viewModel.profile?.nickname, "채림")
        XCTAssertEqual(viewModel.logs.map(\.id), [1])
        XCTAssertTrue(viewModel.hasNextPage)
        XCTAssertEqual(repository.requestedCursors, [nil])

        await viewModel.loadNextPage()

        XCTAssertEqual(viewModel.logs.map(\.id), [1, 2])
        XCTAssertFalse(viewModel.hasNextPage)
        XCTAssertEqual(repository.requestedCursors, [nil, "next-page"])
    }

    private func makeLog(
        id: Int64,
        address: String
    ) -> ProfileLog {
        ProfileLog(
            id: id,
            thumbnailURL: nil,
            address: address,
            videoDurationMillis: 65_000,
            viewCount: 42,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}

private final class ProfileRepositoryStub: ProfileRepository {
    private let profile: MyProfile
    private var pages: [ProfileLogPage]
    private(set) var requestedCursors: [String?] = []

    init(
        profile: MyProfile,
        pages: [ProfileLogPage]
    ) {
        self.profile = profile
        self.pages = pages
    }

    func fetchMyProfile() async throws -> MyProfile {
        profile
    }

    func fetchMyLogs(
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPage {
        requestedCursors.append(cursor)

        guard !pages.isEmpty else {
            return ProfileLogPage(
                logs: [],
                hasNext: false,
                nextCursor: nil
            )
        }

        return pages.removeFirst()
    }

    func updateMyProfile(
        _ update: ProfileUpdate
    ) async throws -> MyProfile {
        profile
    }

    func deleteMyProfile() async throws {}

    func fetchImageData(
        from url: URL
    ) async throws -> Data {
        Data()
    }
}
