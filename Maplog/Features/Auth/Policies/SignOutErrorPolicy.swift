//
//  SignOutErrorPolicy.swift
//  Maplog
//
//  Created by 한채림 on 7/25/26.
//

import Foundation

struct SignOutErrorPresentation: Equatable {
    let message: String?
    let recoveryAction: ErrorPresentation.RecoveryAction
    let shouldEndLocalSession: Bool // 이 오류가 났을 때 앱 안에 저장한 로그인 상태를 끝내야 하는가?
}

enum SignOutErrorPolicy {
    static func presentation(for error: Error) -> SignOutErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultPresentation
        }

        switch apiError {
        case .missingAccessToken:
            return endLocalSessionPresentation

        case .network:
            return retryPresentation("인터넷 연결을 확인한 뒤 다시 시도해 주세요.")

        case .server(let statusCode, let response):
            let errorCode = BackendErrorCode(serverCode: response.code)

            return serverErrorPresentation(for: errorCode, statusCode: statusCode)

        default:
            return defaultPresentation
        }
    }

    private static func serverErrorPresentation(for errorCode: BackendErrorCode, statusCode: Int) -> SignOutErrorPresentation {
        switch errorCode {
        case .expiredAccessToken,
                .invalidAuthentication:
            return endLocalSessionPresentation

        case .unknown:
            if (500...599).contains(statusCode) {
                return retryPresentation("로그아웃 처리 중 문제가 생겼어요. 잠시 후 다시 시도해 주세요.")
            }

            return defaultPresentation

        default:
            return defaultPresentation
        }
    }

    private static func retryPresentation(_ message: String) -> SignOutErrorPresentation {
        SignOutErrorPresentation(
            message: message,
            recoveryAction: .retry,
            shouldEndLocalSession: false
        )
    }

    private static let endLocalSessionPresentation =
    SignOutErrorPresentation(message: nil, recoveryAction: .signIn, shouldEndLocalSession: true)

    private static let defaultPresentation =
    SignOutErrorPresentation(message: "로그아웃 처리 중 오류가 발생했어요. 잠시 후 다시 시도해 주세요.", recoveryAction: .retry, shouldEndLocalSession: false)
}
