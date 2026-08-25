import XCTest
@testable import Maplog

final class LogInteractionRepositoryTests: XCTestCase {
    func testSetLikeForwardsRequestedStateAndMapsResponse() async throws {
        let apiService = LogInteractionAPIServiceStub(
            likeResponse: LogLikeInteractionResponseDTO(
                logID: 501,
                liked: true
            ),
            saveResponse: LogSaveInteractionResponseDTO(
                logID: 501,
                saved: false
            )
        )
        let repository = DefaultLogInteractionRepository(
            apiService: apiService
        )

        let result = try await repository.setLike(
            logID: 501,
            isLiked: true
        )

        XCTAssertEqual(apiService.likeRequest?.logID, 501)
        XCTAssertEqual(apiService.likeRequest?.isLiked, true)
        XCTAssertEqual(result, LogLikeInteractionResult(logID: 501, isLiked: true))
    }

    func testSetSavedForwardsRequestedStateAndMapsResponse() async throws {
        let apiService = LogInteractionAPIServiceStub(
            likeResponse: LogLikeInteractionResponseDTO(
                logID: 501,
                liked: false
            ),
            saveResponse: LogSaveInteractionResponseDTO(
                logID: 501,
                saved: true
            )
        )
        let repository = DefaultLogInteractionRepository(
            apiService: apiService
        )

        let result = try await repository.setSaved(
            logID: 501,
            isSaved: true
        )

        XCTAssertEqual(apiService.saveRequest?.logID, 501)
        XCTAssertEqual(apiService.saveRequest?.isSaved, true)
        XCTAssertEqual(result, LogSaveInteractionResult(logID: 501, isSaved: true))
    }

    func testSetLikeRejectsResponseForDifferentLog() async {
        let apiService = LogInteractionAPIServiceStub(
            likeResponse: LogLikeInteractionResponseDTO(
                logID: 999,
                liked: true
            ),
            saveResponse: LogSaveInteractionResponseDTO(
                logID: 501,
                saved: true
            )
        )
        let repository = DefaultLogInteractionRepository(
            apiService: apiService
        )

        do {
            _ = try await repository.setLike(logID: 501, isLiked: true)
            XCTFail("다른 logId 응답은 성공으로 처리하면 안 됩니다.")
        } catch let error as APIError {
            guard case .invalidResponse = error else {
                return XCTFail("예상하지 못한 APIError: \(error)")
            }
        } catch {
            XCTFail("예상하지 못한 오류: \(error)")
        }
    }
}

private final class LogInteractionAPIServiceStub: LogInteractionAPIService {
    struct LikeRequest: Equatable {
        let logID: Int64
        let isLiked: Bool
    }

    struct SaveRequest: Equatable {
        let logID: Int64
        let isSaved: Bool
    }

    private let likeResponse: LogLikeInteractionResponseDTO
    private let saveResponse: LogSaveInteractionResponseDTO

    private(set) var likeRequest: LikeRequest?
    private(set) var saveRequest: SaveRequest?

    init(
        likeResponse: LogLikeInteractionResponseDTO,
        saveResponse: LogSaveInteractionResponseDTO
    ) {
        self.likeResponse = likeResponse
        self.saveResponse = saveResponse
    }

    func setLike(
        logID: Int64,
        isLiked: Bool
    ) async throws -> LogLikeInteractionResponseDTO {
        likeRequest = LikeRequest(logID: logID, isLiked: isLiked)
        return likeResponse
    }

    func setSaved(
        logID: Int64,
        isSaved: Bool
    ) async throws -> LogSaveInteractionResponseDTO {
        saveRequest = SaveRequest(logID: logID, isSaved: isSaved)
        return saveResponse
    }
}
