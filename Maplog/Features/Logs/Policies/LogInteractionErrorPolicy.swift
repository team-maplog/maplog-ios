enum LogInteractionErrorPolicy {
    static func presentation(
        for error: Error,
        actionName: String
    ) -> ErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultPresentation(actionName: actionName)
        }

        switch apiError {
        case .network:
            return ErrorPresentation(
                message: "\(actionName)을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.",
                recoveryAction: .retry
            )

        case .missingAccessToken:
            return signInPresentation

        case let .server(statusCode, response):
            switch BackendErrorCode(serverCode: response.code) {
            case .expiredAccessToken,
                 .invalidAuthentication,
                 .inactiveUser,
                 .suspendedUser,
                 .pendingUser:
                return signInPresentation

            case .logNotFound, .logNotReadable:
                return ErrorPresentation(
                    message: "이 맵로그를 더 이상 볼 수 없어요.",
                    recoveryAction: .none
                )

            case .unknown where (500...599).contains(statusCode):
                return ErrorPresentation(
                    message: "\(actionName)을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.",
                    recoveryAction: .retry
                )

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

    private static func defaultPresentation(
        actionName: String
    ) -> ErrorPresentation {
        ErrorPresentation(
            message: "\(actionName)을 완료하지 못했어요.",
            recoveryAction: .none
        )
    }
}
