enum PublicProfileErrorPolicy {
    static func isCursorInvalid(
        _ error: Error
    ) -> Bool {
        guard case let APIError.server(_, response) = error else {
            return false
        }

        return BackendErrorCode(serverCode: response.code) == .cursorInvalid
    }

    static func initialPresentation(
        for error: Error
    ) -> ErrorPresentation {
        presentation(for: error, fallbackMessage: "프로필을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
    }

    static func nextPagePresentation(
        for error: Error
    ) -> ErrorPresentation {
        presentation(for: error, fallbackMessage: "맵로그를 더 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
    }

    private static func presentation(
        for error: Error,
        fallbackMessage: String
    ) -> ErrorPresentation {
        guard let apiError = error as? APIError else {
            return ErrorPresentation(
                message: fallbackMessage,
                recoveryAction: .retry
            )
        }

        switch apiError {
        case .network:
            return ErrorPresentation(
                message: "인터넷 연결을 확인한 뒤 다시 시도해 주세요.",
                recoveryAction: .retry
            )

        case .missingAccessToken:
            return signInPresentation

        case let .server(statusCode, response):
            switch BackendErrorCode(serverCode: response.code) {
            case .userNotFound:
                return ErrorPresentation(
                    message: "존재하지 않거나 볼 수 없는 프로필이에요.",
                    recoveryAction: .none
                )

            case .expiredAccessToken,
                 .invalidAuthentication,
                 .inactiveUser,
                 .suspendedUser,
                 .pendingUser:
                return signInPresentation

            case .unknown where (500...599).contains(statusCode):
                return ErrorPresentation(
                    message: fallbackMessage,
                    recoveryAction: .retry
                )

            default:
                return ErrorPresentation(
                    message: fallbackMessage,
                    recoveryAction: .retry
                )
            }

        default:
            return ErrorPresentation(
                message: fallbackMessage,
                recoveryAction: .retry
            )
        }
    }

    private static let signInPresentation = ErrorPresentation(
        message: "로그인 정보가 만료되었어요. 다시 로그인해 주세요.",
        recoveryAction: .signIn
    )
}
