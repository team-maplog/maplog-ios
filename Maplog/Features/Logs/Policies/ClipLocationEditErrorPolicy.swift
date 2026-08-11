//
//  ClipLocationEditErrorPolicy.swift
//  Maplog
//
//  Created by 한채림 on 8/12/26.
//

import Foundation

enum ClipLocationEditErrorPolicy {
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

        case .invalidRequest:
            return ErrorPresentation(
                message: "선택한 위치를 확인할 수 없어요.",
                recoveryAction: .none
            )

        case .server(let statusCode, let response):
            let backendErrorCode = BackendErrorCode(
                serverCode: response.code
            )

            if backendErrorCode == .expiredAccessToken ||
                backendErrorCode == .invalidAuthentication
            {
                return authenticationPresentation
            }

            if (500...599).contains(statusCode) {
                return defaultPresentation
            }

            return defaultPresentation

        default:
            return defaultPresentation
        }
    }

    private static let defaultPresentation = ErrorPresentation(
        message: "주소를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.",
        recoveryAction: .retry
    )

    private static let authenticationPresentation = ErrorPresentation(
        message: "로그인 정보가 만료되었어요. 다시 로그인해 주세요.",
        recoveryAction: .signIn
    )
}
