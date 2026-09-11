import Foundation

enum LogCommentErrorPolicy {
    static func loadPresentation(
        for error: Error
    ) -> ErrorPresentation {
        presentation(
            for: error,
            actionName: "댓글을 불러오기"
        )
    }

    static func actionPresentation(
        for error: Error,
        actionName: String
    ) -> ErrorPresentation {
        presentation(for: error, actionName: actionName)
    }

    private static func presentation(
        for error: Error,
        actionName: String
    ) -> ErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultPresentation(actionName: actionName)
        }

        switch apiError {
        case .network:
            return retryPresentation(actionName: actionName)

        case .missingAccessToken:
            return signInPresentation

        case let .server(statusCode, response):
            switch BackendErrorCode(serverCode: response.code) {
            case .duplicateReport:
                return ErrorPresentation(message: "이미 신고한 댓글이에요.", recoveryAction: .none)
            case .cannotReportOwnContent:
                return ErrorPresentation(message: "내 댓글은 신고할 수 없어요.", recoveryAction: .none)
            case .cannotBlockSelf:
                return ErrorPresentation(message: "자신은 차단할 수 없어요.", recoveryAction: .none)
            case .expiredAccessToken,
                 .invalidAuthentication,
                 .inactiveUser,
                 .suspendedUser,
                 .pendingUser:
                return signInPresentation

            case .commonValidationFailure:
                let fieldMessage = response.data?.first {
                    $0.field == "content" || $0.field == "reason"
                }?.message
                return ErrorPresentation(
                    message: fieldMessage ?? "입력 내용을 확인해 주세요.",
                    recoveryAction: .none
                )

            case .unknown where (500...599).contains(statusCode):
                return retryPresentation(actionName: actionName)

            default:
                return defaultPresentation(actionName: actionName)
            }

        default:
            return defaultPresentation(actionName: actionName)
        }
    }

    private static let signInPresentation = ErrorPresentation(
        message: "로그인 정보가 만료되었어요. 다시 로그인해 주세요.",
        recoveryAction: .signIn
    )

    private static func retryPresentation(
        actionName: String
    ) -> ErrorPresentation {
        ErrorPresentation(
            message: "\(actionName)\(objectParticle(for: actionName)) 완료하지 못했어요. 잠시 후 다시 시도해 주세요.",
            recoveryAction: .retry
        )
    }

    private static func defaultPresentation(
        actionName: String
    ) -> ErrorPresentation {
        ErrorPresentation(
            message: "\(actionName)\(objectParticle(for: actionName)) 완료하지 못했어요.",
            recoveryAction: .none
        )
    }

    private static func objectParticle(
        for text: String
    ) -> String {
        guard let unicodeScalar = text.unicodeScalars.last else {
            return "을"
        }

        let value = unicodeScalar.value
        let hangulStart: UInt32 = 0xAC00
        let hangulEnd: UInt32 = 0xD7A3

        guard (hangulStart...hangulEnd).contains(value) else {
            return "을"
        }

        // 한글 종성 유무에 따라 을/를을 고름. 사용자 문구가 자연스럽게 보이게 함.
        return (value - hangulStart) % 28 == 0 ? "를" : "을"
    }
}
