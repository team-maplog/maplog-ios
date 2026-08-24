import Foundation

struct LogCaptionEditErrorPresentation: Equatable {
    let formMessage: String?
    let captionMessage: String?
    let recoveryAction: ErrorPresentation.RecoveryAction
}

enum LogDetailErrorPolicy {
    static func detailPresentation(
        for error: Error
    ) -> ErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultDetailPresentation
        }

        switch apiError {
        case .network:
            return retryDetailPresentation

        case .missingAccessToken:
            return signInPresentation

        case .server(let statusCode, let response):
            switch BackendErrorCode(serverCode: response.code) {
            case .logNotFound, .logNotReadable:
                return ErrorPresentation(
                    message: "이 맵로그를 더 이상 볼 수 없어요.",
                    recoveryAction: .none
                )

            case .expiredAccessToken, .invalidAuthentication,
                    .inactiveUser, .suspendedUser, .pendingUser:
                return signInPresentation

            case .unknown where (500...599).contains(statusCode):
                return retryDetailPresentation

            default:
                return defaultDetailPresentation
            }

        default:
            return defaultDetailPresentation
        }
    }

    static func captionPresentation(
        for error: Error
    ) -> LogCaptionEditErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultCaptionPresentation
        }

        switch apiError {
        case .network:
            return retryCaptionPresentation

        case .missingAccessToken:
            return signInCaptionPresentation

        case .server(let statusCode, let response):
            switch BackendErrorCode(serverCode: response.code) {
            case .commonValidationFailure:
                let errors = response.data ?? []
                return LogCaptionEditErrorPresentation(
                    formMessage: errors.isEmpty
                        ? "캡션을 확인해 주세요."
                        : nil,
                    captionMessage: errors.first {
                        $0.field == "caption"
                    }?.message,
                    recoveryAction: .none
                )

            case .logNotFound, .logNotReadable:
                return LogCaptionEditErrorPresentation(
                    formMessage: "이 맵로그를 더 이상 수정할 수 없어요.",
                    captionMessage: nil,
                    recoveryAction: .none
                )

            case .logNotOwner:
                return LogCaptionEditErrorPresentation(
                    formMessage: "작성한 맵로그만 수정할 수 있어요.",
                    captionMessage: nil,
                    recoveryAction: .none
                )

            case .expiredAccessToken, .invalidAuthentication,
                    .inactiveUser, .suspendedUser, .pendingUser:
                return signInCaptionPresentation

            case .unknown where (500...599).contains(statusCode):
                return retryCaptionPresentation

            default:
                return defaultCaptionPresentation
            }

        default:
            return defaultCaptionPresentation
        }
    }

    static func deletionPresentation(
        for error: Error
    ) -> ErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultDeletionPresentation
        }

        switch apiError {
        case .network:
            return retryDeletionPresentation

        case .missingAccessToken:
            return signInPresentation

        case .server(let statusCode, let response):
            switch BackendErrorCode(serverCode: response.code) {
            case .logNotOwner:
                return ErrorPresentation(
                    message: "작성한 맵로그만 삭제할 수 있어요.",
                    recoveryAction: .none
                )

            case .expiredAccessToken, .invalidAuthentication,
                    .inactiveUser, .suspendedUser, .pendingUser:
                return signInPresentation

            case .unknown where (500...599).contains(statusCode):
                return retryDeletionPresentation

            default:
                return defaultDeletionPresentation
            }

        default:
            return defaultDeletionPresentation
        }
    }

    static func shouldRemoveFromSourceList(
        for error: Error
    ) -> Bool {
        guard let apiError = error as? APIError,
              case let .server(_, response) = apiError
        else {
            return false
        }

        switch BackendErrorCode(serverCode: response.code) {
        case .logNotFound, .logNotReadable:
            return true

        default:
            return false
        }
    }

    private static let retryDetailPresentation = ErrorPresentation(
        message: "맵로그를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
        recoveryAction: .retry
    )

    private static let defaultDetailPresentation = ErrorPresentation(
        message: "맵로그를 불러오지 못했어요.",
        recoveryAction: .none
    )

    private static let retryCaptionPresentation = LogCaptionEditErrorPresentation(
        formMessage: "캡션을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.",
        captionMessage: nil,
        recoveryAction: .retry
    )

    private static let defaultCaptionPresentation = LogCaptionEditErrorPresentation(
        formMessage: "캡션을 저장하지 못했어요.",
        captionMessage: nil,
        recoveryAction: .none
    )

    private static let signInCaptionPresentation = LogCaptionEditErrorPresentation(
        formMessage: "로그인 정보가 만료되었어요. 다시 로그인해 주세요.",
        captionMessage: nil,
        recoveryAction: .signIn
    )

    private static let retryDeletionPresentation = ErrorPresentation(
        message: "맵로그를 삭제하지 못했어요. 잠시 후 다시 시도해 주세요.",
        recoveryAction: .retry
    )

    private static let defaultDeletionPresentation = ErrorPresentation(
        message: "맵로그를 삭제하지 못했어요.",
        recoveryAction: .none
    )

    private static let signInPresentation = ErrorPresentation(
        message: "로그인 정보가 만료되었어요. 다시 로그인해 주세요.",
        recoveryAction: .signIn
    )
}
