//
//  LogLocationErrorPolicy.swift
//  Maplog
//
//  위치 자동 조회와 사용자의 위치 수정 화면이 공통으로 사용하는 오류 정책
//

import Foundation

enum LogLocationErrorPolicy {
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

            switch backendErrorCode {
            case .locationAddressNotFound:
                return ErrorPresentation(
                    message: "현재 좌표의 주소를 찾지 못했어요. 다시 조회해 주세요.",
                    recoveryAction: .retry
                )

            case .locationLookupFailed:
                return ErrorPresentation(
                    message: "주소를 조회하지 못했어요. 잠시 후 다시 시도해 주세요.",
                    recoveryAction: .retry
                )

            default:
                break
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
