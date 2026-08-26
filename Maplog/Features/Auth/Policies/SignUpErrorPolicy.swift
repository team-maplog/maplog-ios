import Foundation

struct SignUpErrorPresentation: Equatable {
    let formMessage: String?
    let emailMessage: String?
    let passwordMessage: String?
    let passwordConfirmationMessage: String?
    let nicknameMessage: String?
    let termsMessage: String?
    let privacyPolicyMessage: String?
    let recoveryAction: ErrorPresentation.RecoveryAction
}

/// 기술 오류(APIError)를 회원가입 화면의 문구와 입력칸 오류로 변환합니다.
enum SignUpErrorPolicy {
    static func presentation(for error: Error) -> SignUpErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultPresentation
        }

        switch apiError {
        case .network:
            return retryPresentation(
                "인터넷 연결을 확인한 뒤 다시 시도해 주세요."
            )

        case let .server(statusCode, response):
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
    ) -> SignUpErrorPresentation {
        switch BackendErrorCode(serverCode: response.code) {
        case .commonValidationFailure:
            return validationPresentation(from: response)

        case .unknown where (500...599).contains(statusCode):
            return retryPresentation(
                "회원가입 처리 중 문제가 생겼어요. 잠시 후 다시 시도해 주세요."
            )

        default:
            return SignUpErrorPresentation(
                formMessage: response.message.isEmpty
                    ? defaultPresentation.formMessage
                    : response.message,
                emailMessage: nil,
                passwordMessage: nil,
                passwordConfirmationMessage: nil,
                nicknameMessage: nil,
                termsMessage: nil,
                privacyPolicyMessage: nil,
                recoveryAction: .none
            )
        }
    }

    private static func validationPresentation(
        from response: APIErrorResponse
    ) -> SignUpErrorPresentation {
        let fieldErrors = response.data ?? []

        return SignUpErrorPresentation(
            formMessage: fieldErrors.isEmpty
                ? "입력 내용을 확인해 주세요."
                : nil,
            emailMessage: message(for: "email", in: fieldErrors),
            passwordMessage: message(for: "password", in: fieldErrors),
            passwordConfirmationMessage: message(
                for: "passwordConfirmation",
                in: fieldErrors
            ),
            nicknameMessage: message(for: "nickname", in: fieldErrors),
            termsMessage: message(for: "termsAgreed", in: fieldErrors),
            privacyPolicyMessage: message(
                for: "privacyPolicyAgreed",
                in: fieldErrors
            ),
            recoveryAction: .none
        )
    }

    private static func message(
        for field: String,
        in errors: [FieldValidationError]
    ) -> String? {
        errors.first { $0.field == field }?.message
    }

    private static func retryPresentation(
        _ message: String
    ) -> SignUpErrorPresentation {
        SignUpErrorPresentation(
            formMessage: message,
            emailMessage: nil,
            passwordMessage: nil,
            passwordConfirmationMessage: nil,
            nicknameMessage: nil,
            termsMessage: nil,
            privacyPolicyMessage: nil,
            recoveryAction: .retry
        )
    }

    private static let defaultPresentation = SignUpErrorPresentation(
        formMessage: "회원가입 처리 중 오류가 발생했어요. 잠시 후 다시 시도해 주세요.",
        emailMessage: nil,
        passwordMessage: nil,
        passwordConfirmationMessage: nil,
        nicknameMessage: nil,
        termsMessage: nil,
        privacyPolicyMessage: nil,
        recoveryAction: .retry
    )
}
