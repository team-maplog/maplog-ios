import Foundation

enum NotificationErrorPolicy {
    static func presentation(for error: Error) -> ErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultPresentation
        }

        switch apiError {
        case .missingAccessToken:
            return authenticationPresentation

        case .network:
            return retryPresentation

        case let .server(statusCode, response):
            switch BackendErrorCode(serverCode: response.code) {
            case .expiredAccessToken, .invalidAuthentication:
                return authenticationPresentation
            default:
                return (500...599).contains(statusCode)
                    ? retryPresentation
                    : defaultPresentation
            }

        default:
            return defaultPresentation
        }
    }

    static func isCursorInvalid(_ error: Error) -> Bool {
        guard case let APIError.server(_, response) = error else {
            return false
        }

        return BackendErrorCode(serverCode: response.code) == .cursorInvalid
    }

    private static let authenticationPresentation = ErrorPresentation(
        message: "로그인 정보가 만료되었어요. 다시 로그인해 주세요.",
        recoveryAction: .signIn
    )

    private static let retryPresentation = ErrorPresentation(
        message: "알림을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
        recoveryAction: .retry
    )

    private static let defaultPresentation = ErrorPresentation(
        message: "알림을 불러오지 못했어요.",
        recoveryAction: .none
    )
}
