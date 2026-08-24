import Foundation
import XCTest
@testable import Maplog

final class LogDetailRepositoryTests: XCTestCase {
    func testFetchDetailMapsRelativeURLsAndSortsClips() async throws {
        let apiService = LogDetailAPIServiceStub(
            detail: makeDetailDTO()
        )
        let repository = DefaultLogDetailRepository(apiService: apiService)

        let detail = try await repository.fetchDetail(logID: 501)

        XCTAssertEqual(detail.id, 501)
        XCTAssertEqual(detail.author.nickname, "채림")
        XCTAssertEqual(detail.playbackURL?.path, "/api/v1/logs/501/video")
        XCTAssertEqual(detail.clips.map(\.id), [701, 702])
        XCTAssertEqual(detail.clips.map(\.displayOrder), [0, 1])
    }

    func testUpdateCaptionForwardsRequestAndMapsResponse() async throws {
        let apiService = LogDetailAPIServiceStub(
            detail: makeDetailDTO(),
            updatedLog: LogBasicResponseDTO(
                logID: 501,
                caption: "수정한 캡션",
                address: "서울 성동구",
                publishedAt: "2026-08-14T10:30:00",
                viewCount: 12,
                playbackURL: "/api/v1/logs/501/video"
            )
        )
        let repository = DefaultLogDetailRepository(apiService: apiService)

        let result = try await repository.updateCaption(
            logID: 501,
            caption: "수정한 캡션"
        )

        XCTAssertEqual(apiService.updatedLogID, 501)
        XCTAssertEqual(apiService.updateRequest?.caption, "수정한 캡션")
        XCTAssertEqual(result.caption, "수정한 캡션")
    }

    func testDeleteForwardsLogID() async throws {
        let apiService = LogDetailAPIServiceStub(detail: makeDetailDTO())
        let repository = DefaultLogDetailRepository(apiService: apiService)

        try await repository.deleteLog(logID: 501)

        XCTAssertEqual(apiService.deletedLogID, 501)
    }

    private func makeDetailDTO() -> LogDetailResponseDTO {
        LogDetailResponseDTO(
            logID: 501,
            author: LogReelAuthorDTO(
                userID: UUID(),
                nickname: "채림",
                profileImageURL: nil
            ),
            caption: "성수 산책",
            address: "서울 성동구",
            thumbnailURL: "/api/v1/logs/501/thumbnail",
            playbackURL: "/api/v1/logs/501/video",
            publishedAt: "2026-08-16T12:30:37.469888",
            viewCount: 12,
            clips: [
                LogReelClipDTO(
                    clipID: 702,
                    displayOrder: 1,
                    startTimeMillis: 4_000,
                    endTimeMillis: 8_000,
                    location: makeLocationDTO(),
                    thumbnailURL: nil
                ),
                LogReelClipDTO(
                    clipID: 701,
                    displayOrder: 0,
                    startTimeMillis: 0,
                    endTimeMillis: 4_000,
                    location: makeLocationDTO(),
                    thumbnailURL: nil
                )
            ],
            likeCount: 3,
            commentCount: 2,
            likedByViewer: false,
            savedByViewer: true
        )
    }

    private func makeLocationDTO() -> LogReelLocationDTO {
        LogReelLocationDTO(
            name: "서울숲",
            address: "서울 성동구 뚝섬로 273",
            latitude: 37.544,
            longitude: 127.037
        )
    }
}

private final class LogDetailAPIServiceStub: LogDetailAPIService {
    private let detail: LogDetailResponseDTO
    private let updatedLog: LogBasicResponseDTO?

    private(set) var updatedLogID: Int64?
    private(set) var updateRequest: UpdateLogRequestDTO?
    private(set) var deletedLogID: Int64?

    init(
        detail: LogDetailResponseDTO,
        updatedLog: LogBasicResponseDTO? = nil
    ) {
        self.detail = detail
        self.updatedLog = updatedLog
    }

    func fetchLogDetail(
        logID: Int64
    ) async throws -> LogDetailResponseDTO {
        detail
    }

    func updateLogCaption(
        logID: Int64,
        request: UpdateLogRequestDTO
    ) async throws -> LogBasicResponseDTO {
        updatedLogID = logID
        updateRequest = request

        guard let updatedLog else {
            fatalError("This test does not update a log.")
        }

        return updatedLog
    }

    func deleteLog(
        logID: Int64
    ) async throws {
        deletedLogID = logID
    }
}
