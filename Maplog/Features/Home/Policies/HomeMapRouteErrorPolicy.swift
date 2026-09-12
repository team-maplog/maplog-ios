//
//  HomeMapRouteErrorPolicy.swift
//  Maplog
//
//  Created by 한채림 on 8/22/26.
// 지도 패널 전용 오류 정책

import Foundation

enum HomeMapRouteErrorPolicy {
    static func presentation(
        for error: Error
    ) -> ErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultPresentation
        }

        switch apiError {
        case .network:
            return retryPresentation

        case .missingAccessToken:
            return authenticationPresentation

        case let .server(statusCode, response):
            let errorCode = BackendErrorCode(
                serverCode: response.code
            )

            switch errorCode {
            case .expiredAccessToken,
                 .invalidAuthentication:
                return authenticationPresentation

            default:
                if (500...599).contains(statusCode) {
                    return retryPresentation
                }

                return defaultPresentation
            }

        default:
            return defaultPresentation
        }
    }

    private static let retryPresentation = ErrorPresentation(
        message: "경로를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
        recoveryAction: .retry
    )

    private static let authenticationPresentation = ErrorPresentation(
        message: "로그인 정보가 만료되었어요. 다시 로그인해 주세요.",
        recoveryAction: .signIn
    )

    private static let defaultPresentation = ErrorPresentation(
        message: "이 로그의 경로 정보를 불러오지 못했어요.",
        recoveryAction: .none
    )
}
