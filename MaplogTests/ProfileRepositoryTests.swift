import Foundation
import XCTest
@testable import Maplog

final class ProfileRepositoryTests: XCTestCase {
    func testFetchMyLogsAcceptsMicrosecondLocalDateTime() async throws {
        let apiService = ProfileAPIServiceStub(
            logPage: ProfileLogPageDTO(
                content: [
                    ProfileLogResponseDTO(
                        logID: 1,
                        thumbnailURL: nil,
                        address: "서울 성수동",
                        videoDurationMillis: 65_000,
                        viewCount: 42,
                        createdAt: "2026-08-16T12:30:37.469888"
                    )
                ],
                hasNext: false,
                nextCursor: nil
            )
        )
        let repository = DefaultProfileRepository(apiService: apiService)

        let page = try await repository.fetchMyLogs(
            cursor: nil,
            size: 20
        )

        XCTAssertEqual(page.logs.map(\.id), [1])
    }

    func testUpdateMyProfileUsesUploadedImageFileID() async throws {
        let apiService = ProfileAPIServiceStub(
            logPage: ProfileLogPageDTO(
                content: [],
                hasNext: false,
                nextCursor: nil
            ),
            updatedProfile: makeProfileDTO(
                nickname: "수정된채림",
                bio: "새로운 소개"
            )
        )
        let repository = DefaultProfileRepository(apiService: apiService)

        let profile = try await repository.updateMyProfile(
            ProfileUpdate(
                nickname: "수정된채림",
                bio: "새로운 소개",
                newProfileImageData: Data([0x01])
            )
        )

        XCTAssertEqual(apiService.uploadedImageData, Data([0x01]))
        XCTAssertEqual(apiService.updateRequest?.profileImageFileID, 777)
        XCTAssertEqual(profile.nickname, "수정된채림")
        XCTAssertEqual(profile.bio, "새로운 소개")
    }

    func testFetchPublicProfileMapsViewerFollowState() async throws {
        let publicProfile = PublicProfileResponseDTO(
            userID: UUID(),
            nickname: "slow.seoul",
            profileImageURL: "/api/v1/files/31",
            bio: "서울의 느린 산책을 기록합니다.",
            followerCount: 14,
            followingCount: 9,
            logCount: 21,
            followedByViewer: true,
            createdAt: "2026-07-10T09:00:00"
        )
        let apiService = ProfileAPIServiceStub(
            logPage: ProfileLogPageDTO(
                content: [],
                hasNext: false,
                nextCursor: nil
            ),
            publicProfile: publicProfile
        )
        let repository = DefaultProfileRepository(apiService: apiService)

        let profile = try await repository.fetchPublicProfile(
            nickname: "slow.seoul"
        )

        XCTAssertEqual(profile.nickname, "slow.seoul")
        XCTAssertTrue(profile.isFollowedByViewer)
        XCTAssertEqual(profile.profileImageURL?.path, "/api/v1/files/31")
    }

    private func makeProfileDTO(
        nickname: String,
        bio: String
    ) -> MyProfileResponseDTO {
        MyProfileResponseDTO(
            userID: UUID(),
            nickname: nickname,
            profileImageURL: nil,
            bio: bio,
            followerCount: 0,
            followingCount: 0,
            logCount: 0
        )
    }
}

private final class ProfileAPIServiceStub: ProfileAPIService {
    private let logPage: ProfileLogPageDTO
    private let updatedProfile: MyProfileResponseDTO?
    private let publicProfile: PublicProfileResponseDTO?
    private(set) var uploadedImageData: Data?
    private(set) var updateRequest: UpdateMyProfileRequestDTO?

    init(
        logPage: ProfileLogPageDTO,
        updatedProfile: MyProfileResponseDTO? = nil,
        publicProfile: PublicProfileResponseDTO? = nil
    ) {
        self.logPage = logPage
        self.updatedProfile = updatedProfile
        self.publicProfile = publicProfile
    }

    func fetchMyProfile() async throws -> MyProfileResponseDTO {
        fatalError("This test does not request a profile.")
    }

    func fetchPublicProfile(
        nickname: String
    ) async throws -> PublicProfileResponseDTO {
        guard let publicProfile else {
            fatalError("This test does not request a public profile.")
        }

        return publicProfile
    }

    func fetchMyLogs(
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPageDTO {
        logPage
    }

    func fetchPublicProfileLogs(
        nickname: String,
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPageDTO {
        fatalError("This test does not request public profile logs.")
    }

    func updateMyProfile(
        request: UpdateMyProfileRequestDTO
    ) async throws -> MyProfileResponseDTO {
        updateRequest = request

        guard let updatedProfile else {
            fatalError("This test does not update a profile.")
        }

        return updatedProfile
    }

    func uploadProfileImage(
        imageData: Data
    ) async throws -> ProfileImageUploadResponseDTO {
        uploadedImageData = imageData
        return ProfileImageUploadResponseDTO(fileID: 777)
    }

    func deleteMyProfile() async throws {}

    func fetchImageData(
        from url: URL
    ) async throws -> Data {
        Data()
    }
}
