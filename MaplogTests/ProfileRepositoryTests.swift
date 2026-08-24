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
    private(set) var uploadedImageData: Data?
    private(set) var updateRequest: UpdateMyProfileRequestDTO?

    init(
        logPage: ProfileLogPageDTO,
        updatedProfile: MyProfileResponseDTO? = nil
    ) {
        self.logPage = logPage
        self.updatedProfile = updatedProfile
    }

    func fetchMyProfile() async throws -> MyProfileResponseDTO {
        fatalError("This test does not request a profile.")
    }

    func fetchMyLogs(
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPageDTO {
        logPage
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
