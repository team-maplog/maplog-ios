import XCTest
@testable import Maplog

final class LogPublishErrorPolicyTests: XCTestCase {
    func testShowsTheRepresentativeAddressValidationError() {
        let presentation = LogPublishErrorPolicy.presentation(
            for: APIError.server(
                statusCode: 400,
                response: APIErrorResponse(
                    successFlag: false,
                    code: "COMMON-014",
                    message: "요청 인자가 올바르지 않습니다.",
                    data: [
                        FieldValidationError(
                            field: "address",
                            rejectedValue: "",
                            message: "Log address is required."
                        )
                    ]
                )
            )
        )

        XCTAssertEqual(presentation.message, "대표 위치 주소를 확인해 주세요.")
        XCTAssertEqual(presentation.recoveryAction, .none)
    }

    func testExplainsAnInvalidIdempotencyKeyInsteadOfShowingGenericInputError() {
        let presentation = LogPublishErrorPolicy.presentation(
            for: APIError.server(
                statusCode: 400,
                response: APIErrorResponse(
                    successFlag: false,
                    code: "LOG-014",
                    message: "Idempotency-Key가 올바르지 않습니다.",
                    data: nil
                )
            )
        )

        XCTAssertEqual(presentation.message, "발행 요청을 준비하지 못했어요. 다시 시도해 주세요.")
        XCTAssertEqual(presentation.recoveryAction, .retry)
    }
}
