enum ProfileErrorPolicy {
    static func isCursorInvalid(
        _ error: Error
    ) -> Bool {
        guard case let APIError.server(_, response) = error else {
            return false
        }

        return BackendErrorCode(serverCode: response.code) == .cursorInvalid
    }

    static func presentation(
        for error: Error
    ) -> ErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultPresentation
        }

        switch apiError {
        case .network:
            return ErrorPresentation(
                message: "인터넷 연결을 확인한 뒤 다시 시도해 주세요.",
                recoveryAction: .retry
            )

        case .missingAccessToken:
            return authenticationPresentation

        case .server(let statusCode, let response):
            return serverErrorPresentation(
                code: BackendErrorCode(serverCode: response.code),
                statusCode: statusCode
            )

        default:
            return defaultPresentation
        }
    }

    private static func serverErrorPresentation(
        code: BackendErrorCode,
        statusCode: Int
    ) -> ErrorPresentation {
        switch code {
        case .expiredAccessToken, .invalidAuthentication:
            return authenticationPresentation

        case .inactiveUser, .suspendedUser, .pendingUser:
            return ErrorPresentation(
                message: "현재 계정 상태에서는 프로필을 볼 수 없어요.",
                recoveryAction: .signIn
            )

        case .unknown:
            if (500...599).contains(statusCode) {
                return ErrorPresentation(
                    message: "프로필을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
                    recoveryAction: .retry
                )
            }
            return defaultPresentation

        default:
            return defaultPresentation
        }
    }

    private static let defaultPresentation = ErrorPresentation(
        message: "프로필을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
        recoveryAction: .retry
    )

    private static let authenticationPresentation = ErrorPresentation(
        message: "로그인 정보가 만료되었어요. 다시 로그인해 주세요.",
        recoveryAction: .signIn
    )
}
