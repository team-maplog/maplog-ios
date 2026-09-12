import XCTest
@testable import Maplog

final class LogCommentRepositoryTests: XCTestCase {
    func testModerationServerCodesProduceSpecificNonRetryMessages() {
        for (code, status, message) in [
            ("REPORT-002", 409, "이미 신고한 콘텐츠예요."),
            ("REPORT-003", 400, "내 콘텐츠는 신고할 수 없어요."),
            ("BLOCK-001", 400, "자신은 차단할 수 없어요.")
        ] {
            let error = APIError.server(statusCode: status, response: APIErrorResponse(
                successFlag: false, code: code, message: "서버 문구", data: nil))
            let result = LogCommentErrorPolicy.actionPresentation(for: error, actionName: "댓글 신고")
            XCTAssertEqual(result.message, message)
            XCTAssertEqual(result.recoveryAction, .none)
        }
    }

    func testReportTrimsReasonAndRejectsEmptyOrTooLongInputBeforeRequest() async throws {
        let response = makeCommentResponse()
        let service = LogCommentAPIServiceStub(comments: [], createResponse: response,
            updateResponse: response, likeResponse: .init(commentID: 31, liked: false))
        let repository = DefaultLogCommentRepository(apiService: service)
        for reason in ["   ", String(repeating: "가", count: 1001)] {
            do {
                try await repository.reportComment(commentID: 31, reason: reason)
                XCTFail("Invalid report should fail")
            } catch { XCTAssertNil(service.reportRequest) }
        }
        try await repository.reportComment(commentID: 31, reason: "  욕설  ")
        XCTAssertEqual(service.reportRequest?.reason, "욕설")
        XCTAssertEqual(service.reportRequest?.targetId, 31)
        let encoded = try JSONEncoder().encode(XCTUnwrap(service.reportRequest))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["targetType"] as? String, "COMMENT")
    }

    func testBlockRejectsWrongUserOrUnblockedResponse() async {
        let response = makeCommentResponse()
        let service = LogCommentAPIServiceStub(comments: [], createResponse: response,
            updateResponse: response, likeResponse: .init(commentID: 31, liked: false))
        let repository = DefaultLogCommentRepository(apiService: service)
        let userID = UUID()
        for result in [CommentAuthorBlockStateDTO(userId: UUID(), blocked: true),
                       CommentAuthorBlockStateDTO(userId: userID, blocked: false)] {
            service.blockResponse = result
            do {
                try await repository.blockAuthor(userID: userID)
                XCTFail("Mismatched state should fail")
            } catch {
                guard case APIError.invalidResponse = error else {
                    return XCTFail("Expected invalid response")
                }
            }
        }
    }

    func testFetchCommentsMapsTopLevelParentIDToNil() async throws {
        let response = makeCommentResponse(parentCommentID: 0)
        let apiService = LogCommentAPIServiceStub(
            comments: [response],
            createResponse: response,
            updateResponse: response,
            likeResponse: LogCommentLikeStateResponseDTO(
                commentID: response.commentID,
                liked: true
            )
        )
        let repository = DefaultLogCommentRepository(apiService: apiService)

        let comments = try await repository.fetchComments(logID: 100)

        XCTAssertEqual(apiService.fetchRequestedLogID, 100)
        XCTAssertEqual(comments.count, 1)
        XCTAssertNil(comments[0].parentCommentID)
        XCTAssertEqual(comments[0].author.nickname, "maploger")
        XCTAssertEqual(comments[0].likeCount, 3)
    }

    func testFetchCommentsAcceptsDeletedCommentWithNullContentAndLocalDateTime() async throws {
        let responseData = Data(
            """
            {
              "successFlag": true,
              "code": "SUCCESS-002",
              "message": "Fetched successfully.",
              "data": [
                {
                  "commentId": 31,
                  "author": {
                    "userId": "3FA85F64-5717-4562-B3FC-2C963F66AFA6",
                    "nickname": "maploger",
                    "profileImageUrl": null
                  },
                  "parentCommentId": null,
                  "content": null,
                  "deleted": true,
                  "createdAt": "2026-09-02T14:06:36",
                  "updatedAt": "2026-09-02T14:06:36",
                  "likeCount": 0,
                  "likedByViewer": false
                }
              ]
            }
            """.utf8
        )
        let response = try JSONDecoder().decode(
            APIResponse<[LogCommentResponseDTO]>.self,
            from: responseData
        )
        let deletedComment = try XCTUnwrap(response.data?.first)
        let apiService = LogCommentAPIServiceStub(
            comments: [deletedComment],
            createResponse: makeCommentResponse(),
            updateResponse: makeCommentResponse(),
            likeResponse: LogCommentLikeStateResponseDTO(
                commentID: 31,
                liked: false
            )
        )
        let repository = DefaultLogCommentRepository(apiService: apiService)

        let comments = try await repository.fetchComments(logID: 100)

        XCTAssertEqual(comments.count, 1)
        XCTAssertTrue(comments[0].isDeleted)
        XCTAssertEqual(comments[0].content, "")
        XCTAssertEqual(
            comments[0].createdAt,
            makeKoreanLocalDate(
                year: 2026,
                month: 9,
                day: 2,
                hour: 14,
                minute: 6,
                second: 36
            )
        )
    }

    func testCreateCommentForwardsDraftAndMapsResponse() async throws {
        let response = makeCommentResponse(parentCommentID: 11)
        let apiService = LogCommentAPIServiceStub(
            comments: [],
            createResponse: response,
            updateResponse: response,
            likeResponse: LogCommentLikeStateResponseDTO(
                commentID: response.commentID,
                liked: false
            )
        )
        let repository = DefaultLogCommentRepository(apiService: apiService)

        let comment = try await repository.createComment(
            logID: 100,
            draft: LogCommentDraft(
                content: "좋은 장소네요",
                parentCommentID: 11
            )
        )

        XCTAssertEqual(apiService.createRequest?.logID, 100)
        XCTAssertEqual(apiService.createRequest?.request.content, "좋은 장소네요")
        XCTAssertEqual(apiService.createRequest?.request.parentCommentID, 11)
        XCTAssertEqual(comment.parentCommentID, 11)
    }

    func testUpdateCommentRejectsResponseForDifferentComment() async {
        let response = makeCommentResponse(commentID: 999)
        let apiService = LogCommentAPIServiceStub(
            comments: [],
            createResponse: response,
            updateResponse: response,
            likeResponse: LogCommentLikeStateResponseDTO(
                commentID: 999,
                liked: true
            )
        )
        let repository = DefaultLogCommentRepository(apiService: apiService)

        do {
            _ = try await repository.updateComment(
                commentID: 100,
                content: "수정한 댓글"
            )
            XCTFail("다른 commentId 응답을 성공으로 처리하면 안 됩니다.")
        } catch let error as APIError {
            guard case .invalidResponse = error else {
                return XCTFail("예상하지 못한 APIError: \(error)")
            }
        } catch {
            XCTFail("예상하지 못한 오류: \(error)")
        }
    }

    func testSetLikeForwardsRequestedStateAndMapsResponse() async throws {
        let response = makeCommentResponse()
        let apiService = LogCommentAPIServiceStub(
            comments: [],
            createResponse: response,
            updateResponse: response,
            likeResponse: LogCommentLikeStateResponseDTO(
                commentID: 31,
                liked: true
            )
        )
        let repository = DefaultLogCommentRepository(apiService: apiService)

        let result = try await repository.setLike(
            commentID: 31,
            isLiked: true
        )

        XCTAssertEqual(apiService.likeRequest?.commentID, 31)
        XCTAssertEqual(apiService.likeRequest?.isLiked, true)
        XCTAssertEqual(
            result,
            LogCommentLikeState(commentID: 31, isLiked: true)
        )
    }

    func testDeleteSuccessResponseAllowsEmptyData() throws {
        let responseData = Data(
            """
            {
              "successFlag": true,
              "code": "SUCCESS-004",
              "message": "Deleted successfully.",
              "data": null
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(
            APIResponse<EmptyCommentDeletePayload>.self,
            from: responseData
        )

        XCTAssertTrue(response.successFlag)
        XCTAssertEqual(response.code, "SUCCESS-004")
        XCTAssertNil(response.data)
    }

    func testCommentActionErrorIncludesTheActualActionName() {
        let presentation = LogCommentErrorPolicy.actionPresentation(
            for: APIError.network(URLError(.notConnectedToInternet)),
            actionName: "댓글 삭제"
        )

        XCTAssertEqual(
            presentation.message,
            "댓글 삭제를 완료하지 못했어요. 잠시 후 다시 시도해 주세요."
        )
    }

    private func makeCommentResponse(
        commentID: Int64 = 31,
        parentCommentID: Int64? = nil,
        content: String? = "좋은 장소네요",
        deleted: Bool = false
    ) -> LogCommentResponseDTO {
        LogCommentResponseDTO(
            commentID: commentID,
            author: LogCommentAuthorDTO(
                userID: UUID(uuidString: "3FA85F64-5717-4562-B3FC-2C963F66AFA6")!,
                nickname: "maploger",
                profileImageURL: nil
            ),
            parentCommentID: parentCommentID,
            content: content,
            deleted: deleted,
            createdAt: "2026-08-25T16:39:17.005Z",
            updatedAt: "2026-08-25T16:39:17.005Z",
            likeCount: 3,
            likedByViewer: false
        )
    }

    private func makeKoreanLocalDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return components.date!
    }
}

private struct EmptyCommentDeletePayload: Decodable {}

private final class LogCommentAPIServiceStub: LogCommentAPIService {
    var reportRequest: ContentReportRequestDTO?
    var blockResponse: CommentAuthorBlockStateDTO?
    func reportContent(request: ContentReportRequestDTO) async throws -> CommentReportReceiptDTO {
        reportRequest = request
        return CommentReportReceiptDTO(reportId: 1, status: "PENDING", createdAt: "2026-09-12T00:00:00")
    }
    func blockAuthor(userID: UUID) async throws -> CommentAuthorBlockStateDTO {
        blockResponse ?? CommentAuthorBlockStateDTO(userId: userID, blocked: true)
    }
    struct CreateRequest {
        let logID: Int64
        let request: CreateLogCommentRequestDTO
    }

    struct UpdateRequest {
        let commentID: Int64
        let request: UpdateLogCommentRequestDTO
    }

    struct LikeRequest {
        let commentID: Int64
        let isLiked: Bool
    }

    private let comments: [LogCommentResponseDTO]
    private let createResponse: LogCommentResponseDTO
    private let updateResponse: LogCommentResponseDTO
    private let likeResponse: LogCommentLikeStateResponseDTO

    private(set) var fetchRequestedLogID: Int64?
    private(set) var createRequest: CreateRequest?
    private(set) var updateRequest: UpdateRequest?
    private(set) var deletedCommentID: Int64?
    private(set) var likeRequest: LikeRequest?

    init(
        comments: [LogCommentResponseDTO],
        createResponse: LogCommentResponseDTO,
        updateResponse: LogCommentResponseDTO,
        likeResponse: LogCommentLikeStateResponseDTO
    ) {
        self.comments = comments
        self.createResponse = createResponse
        self.updateResponse = updateResponse
        self.likeResponse = likeResponse
    }

    func fetchComments(
        logID: Int64
    ) async throws -> [LogCommentResponseDTO] {
        fetchRequestedLogID = logID
        return comments
    }

    func createComment(
        logID: Int64,
        request: CreateLogCommentRequestDTO
    ) async throws -> LogCommentResponseDTO {
        createRequest = CreateRequest(logID: logID, request: request)
        return createResponse
    }

    func updateComment(
        commentID: Int64,
        request: UpdateLogCommentRequestDTO
    ) async throws -> LogCommentResponseDTO {
        updateRequest = UpdateRequest(commentID: commentID, request: request)
        return updateResponse
    }

    func deleteComment(
        commentID: Int64
    ) async throws {
        deletedCommentID = commentID
    }

    func setLike(
        commentID: Int64,
        isLiked: Bool
    ) async throws -> LogCommentLikeStateResponseDTO {
        likeRequest = LikeRequest(commentID: commentID, isLiked: isLiked)
        return likeResponse
    }
}
