//
//  SignInErrorPolicy.swift
//  Maplog
//
//  Created by 한채림 on 7/24/26.
//

import Foundation

struct SignInErrorPresentation: Equatable {
    let formMessage: String?
    let emailMessage: String?
    let passwordMessage: String?
    let recoveryAction: ErrorPresentation.RecoveryAction
}

enum SignInErrorPolicy {
    static func presentation(for error: Error) -> SignInErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultPresentation
        }

        switch apiError {
        case .network:
            return SignInErrorPresentation(
                formMessage: "인터넷 연결을 확인한 뒤 다시 시도해 주세요.",
                emailMessage: nil,
                passwordMessage: nil,
                recoveryAction: .retry)

        case .server(let statusCode, let response):
            let errorCode = BackendErrorCode(serverCode: response.code)

            return serverErrorPresentation(for: errorCode, response: response, statusCode: statusCode)

        default:
            return defaultPresentation
        }
    }

    private static func serverErrorPresentation(
        for errorCode: BackendErrorCode,
        response: APIErrorResponse,
        statusCode: Int) -> SignInErrorPresentation {
        switch errorCode {
        case .commonValidationFailure:
            return validationPresentation(from: response)

        case .userNotFound:
            return SignInErrorPresentation(
                formMessage: nil,
                emailMessage: "등록되지 않은 이메일입니다.",
                passwordMessage: nil,
                recoveryAction: .none)

        case .wrongPassword:
                    return SignInErrorPresentation(
                        formMessage: nil,
                        emailMessage: nil,
                        passwordMessage: "비밀번호가 올바르지 않습니다.",
                        recoveryAction: .none
                    )

                case .inactiveUser:
                    return formError(
                        "비활성화된 계정입니다. 계정 상태를 확인해 주세요."
                    )

                case .suspendedUser:
                    return formError(
                        "정지된 계정입니다. 관리자에게 문의해 주세요."
                    )

                case .pendingUser:
                    return formError(
                        "승인 대기 중인 계정입니다."
                    )

                case .unknown:
                    if (500...599).contains(statusCode) {
                        return SignInErrorPresentation(
                            formMessage: "로그인 처리 중 문제가 생겼어요. 잠시 후 다시 시도해 주세요.",
                            emailMessage: nil,
                            passwordMessage: nil,
                            recoveryAction: .retry
                        )
                    }
            return defaultPresentation

        default:
            return defaultPresentation
        }
    }

    private static func validationPresentation(from response: APIErrorResponse) -> SignInErrorPresentation {
        let fieldErrors = response.data ?? []

        return SignInErrorPresentation(
            formMessage: fieldErrors.isEmpty ? "입력 내용을 확인해 주세요." : nil,
            emailMessage: fieldErrors.first { $0.field == "email" }?.message,
            passwordMessage: fieldErrors.first { $0.field == "password"}?.message,
            recoveryAction: .none)
    }

    private static func formError(_ message: String) -> SignInErrorPresentation {
        SignInErrorPresentation(
            formMessage: message,
            emailMessage: nil,
            passwordMessage: nil,
            recoveryAction: .none)
    }

    private static let defaultPresentation = SignInErrorPresentation(
        formMessage: "로그인 처리 중 오류가 발생했어요. 잠시 후 다시 시도해 주세요.",
                emailMessage: nil,
                passwordMessage: nil,
                recoveryAction: .none)
}
