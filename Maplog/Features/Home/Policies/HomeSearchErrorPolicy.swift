import Foundation

enum HomeSearchErrorPolicy {
    static func initialPresentation(
        for error: Error
    ) -> ErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultPresentation
        }

        switch apiError {
        case .missingAccessToken:
            return authenticationPresentation

        case let .server(statusCode, response):
            switch BackendErrorCode(serverCode: response.code) {
            case .expiredAccessToken, .invalidAuthentication:
                return authenticationPresentation

            case .tourAPIUnavailable, .tourAPIRequestFailed:
                return tourismServicePresentation

            default:
                return (500...599).contains(statusCode)
                    ? retryPresentation
                    : defaultPresentation
            }

        case .network:
            return retryPresentation

        default:
            return defaultPresentation
        }
    }

    static func nextPagePresentation(
        for error: Error
    ) -> ErrorPresentation {
        initialPresentation(for: error)
    }

    static func explorePresentation(
        for error: Error
    ) -> ErrorPresentation {
        guard let apiError = error as? APIError else {
            return exploreDefaultPresentation
        }

        switch apiError {
        case .missingAccessToken:
            return authenticationPresentation

        case let .server(statusCode, response):
            switch BackendErrorCode(serverCode: response.code) {
            case .expiredAccessToken, .invalidAuthentication:
                return authenticationPresentation

            default:
                return (500...599).contains(statusCode)
                    ? exploreRetryPresentation
                    : exploreDefaultPresentation
            }

        case .network:
            return exploreRetryPresentation

        default:
            return exploreDefaultPresentation
        }
    }

    static func isCursorInvalid(
        _ error: Error
    ) -> Bool {
        guard case let APIError.server(_, response) = error else {
            return false
        }

        return BackendErrorCode(serverCode: response.code) == .cursorInvalid
    }

    private static let retryPresentation = ErrorPresentation(
        message: "검색 결과를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
        recoveryAction: .retry
    )

    private static let tourismServicePresentation = ErrorPresentation(
        message: "관광 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
        recoveryAction: .retry
    )

    private static let authenticationPresentation = ErrorPresentation(
        message: "로그인 정보가 만료되었어요. 다시 로그인해 주세요.",
        recoveryAction: .signIn
    )

    private static let defaultPresentation = ErrorPresentation(
        message: "검색 결과를 불러오지 못했어요.",
        recoveryAction: .none
    )

    private static let exploreRetryPresentation = ErrorPresentation(
        message: "최근 맵로그를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
        recoveryAction: .retry
    )

    private static let exploreDefaultPresentation = ErrorPresentation(
        message: "최근 맵로그를 불러오지 못했어요.",
        recoveryAction: .none
    )
}
