import Foundation

struct ProfileEditErrorPresentation: Equatable {
    let formMessage: String?
    let nicknameMessage: String?
    let bioMessage: String?
    let recoveryAction: ErrorPresentation.RecoveryAction
}

enum ProfileEditErrorPolicy {
    static func presentation(
        for error: Error
    ) -> ProfileEditErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultPresentation
        }

        switch apiError {
        case .network:
            return ProfileEditErrorPresentation(
                formMessage: "인터넷 연결을 확인한 뒤 다시 시도해 주세요.",
                nicknameMessage: nil,
                bioMessage: nil,
                recoveryAction: .retry
            )

        case .missingAccessToken:
            return signInPresentation

        case .server(let statusCode, let response):
            return serverPresentation(
                response: response,
                statusCode: statusCode
            )

        default:
            return defaultPresentation
        }
    }

    private static func serverPresentation(
        response: APIErrorResponse,
        statusCode: Int
    ) -> ProfileEditErrorPresentation {
        switch BackendErrorCode(serverCode: response.code) {
        case .commonValidationFailure:
            let errors = response.data ?? []
            return ProfileEditErrorPresentation(
                formMessage: errors.isEmpty
                    ? "입력 내용을 확인해 주세요."
                    : nil,
                nicknameMessage: errors.first {
                    $0.field == "nickname"
                }?.message,
                bioMessage: errors.first {
                    $0.field == "bio"
                }?.message,
                recoveryAction: .none
            )

        case .expiredAccessToken, .invalidAuthentication,
                .inactiveUser, .suspendedUser, .pendingUser:
            return signInPresentation

        case .unknown where (500...599).contains(statusCode):
            return ProfileEditErrorPresentation(
                formMessage: "프로필을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.",
                nicknameMessage: nil,
                bioMessage: nil,
                recoveryAction: .retry
            )

        default:
            return defaultPresentation
        }
    }

    private static let defaultPresentation = ProfileEditErrorPresentation(
        formMessage: "프로필을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.",
        nicknameMessage: nil,
        bioMessage: nil,
        recoveryAction: .retry
    )

    private static let signInPresentation = ProfileEditErrorPresentation(
        formMessage: "로그인 정보가 만료되었어요. 다시 로그인해 주세요.",
        nicknameMessage: nil,
        bioMessage: nil,
        recoveryAction: .signIn
    )
}
