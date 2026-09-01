//
//  SocialSignInErrorPolicy.swift
//  Maplog
//

import Foundation

struct SocialSignInErrorPresentation: Equatable {
    let message: String?
    let recoveryAction: ErrorPresentation.RecoveryAction
}

enum SocialSignInErrorPolicy {
    static func presentation(for error: Error) -> SocialSignInErrorPresentation {
        if let sessionError = error as? OAuthWebAuthenticationSessionError,
           sessionError == .cancelled {
            return SocialSignInErrorPresentation(message: nil, recoveryAction: .none)
        }

        if error is OAuthCallbackError {
            return retryPresentation("로그인 정보를 확인하지 못했어요. 처음부터 다시 시도해 주세요.")
        }

        guard let apiError = error as? APIError else {
            return defaultPresentation
        }

        switch apiError {
        case .network:
            return retryPresentation("인터넷 연결을 확인한 뒤 다시 시도해 주세요.")

        case .server(let statusCode, let response):
            return serverErrorPresentation(
                for: BackendErrorCode(serverCode: response.code),
                statusCode: statusCode
            )

        default:
            return defaultPresentation
        }
    }

    private static func serverErrorPresentation(
        for errorCode: BackendErrorCode,
        statusCode: Int
    ) -> SocialSignInErrorPresentation {
        switch errorCode {
        case .oauthEmailPermissionRequired:
            return SocialSignInErrorPresentation(
                message: "이메일 제공에 동의한 뒤 다시 시도해 주세요.",
                recoveryAction: .retry
            )

        case .oauthStateExpired, .oauthHandoffInvalid:
            return retryPresentation("로그인 시간이 만료되었어요. 처음부터 다시 시도해 주세요.")

        case .oauthEmailAlreadyInUse:
            return SocialSignInErrorPresentation(
                message: "같은 이메일로 만든 계정이 있어요. 기존 로그인 방법을 이용해 주세요.",
                recoveryAction: .none
            )

        case .oauthHandoffStoreUnavailable:
            return retryPresentation("로그인을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.")

        case .expiredAccessToken, .invalidAuthentication:
            return retryPresentation("로그인 정보를 확인하지 못했어요. 처음부터 다시 시도해 주세요.")

        case .requestRateLimited:
            return retryPresentation("요청이 많아요. 잠시 후 다시 시도해 주세요.")

        default:
            if (500...599).contains(statusCode) {
                return retryPresentation("로그인을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.")
            }
            return defaultPresentation
        }
    }

    private static func retryPresentation(_ message: String) -> SocialSignInErrorPresentation {
        SocialSignInErrorPresentation(message: message, recoveryAction: .retry)
    }

    private static let defaultPresentation = SocialSignInErrorPresentation(
        message: "로그인 처리 중 오류가 발생했어요. 잠시 후 다시 시도해 주세요.",
        recoveryAction: .none
    )
}
