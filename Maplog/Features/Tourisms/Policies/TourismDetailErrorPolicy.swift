//
//  TourismDetailErrorPolicy.swift
//  Maplog
//
//  Created by 한채림 on 7/26/26.
//

enum TourismDetailErrorPolicy {
    static func presentation(for error: Error) -> ErrorPresentation {
        if case TourismRepositoryError.requestInvalidated = error {
            return ErrorPresentation(message: "관광 정보를 다시 불러와 주세요.", recoveryAction: .retry)
        }
        guard let apiError = error as? APIError else {
            return defaultPresentation
        }

        switch apiError {
        case .network:
            return ErrorPresentation(message: "인터넷 연결을 확인한 뒤 다시 시도해 주세요.", recoveryAction: .retry)

        case .missingAccessToken:
            return authenticationPresentation

        case .invalidRequest:
            return invalidLinkPresentation

        case .server(let statusCode, let response):
            let errorCode = BackendErrorCode(serverCode: response.code)

            return serverErrorPresentation(
                for: errorCode,
                statusCode: statusCode
            )

        default:
            return defaultPresentation
        }
    }

    private static func serverErrorPresentation(for errorCode: BackendErrorCode, statusCode: Int) -> ErrorPresentation {
        switch errorCode {
        case .commonInvalidRequest:
            return invalidLinkPresentation

        case .tourismNotFound:
            return ErrorPresentation(
                message: "관광 정보를 찾을 수 없어요.",
                recoveryAction: .none
            )

        case .tourAPIRequestFailed:
            return ErrorPresentation(
                message: "관광 상세 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
                recoveryAction: .retry
            )

        case .tourAPIUnavailable:
            return ErrorPresentation(
                message: "현재 관광 상세 정보를 이용할 수 없어요. 잠시 후 다시 시도해 주세요.",
                recoveryAction: .none
            )

        case .expiredAccessToken, .invalidAuthentication:
            return authenticationPresentation

        case .unknown:
            if (500...599).contains(statusCode) {
                return ErrorPresentation(
                    message: "관광 상세 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
                    recoveryAction: .retry
                )
            }

            return defaultPresentation

        default:
            return defaultPresentation
        }
    }

    private static let invalidLinkPresentation = ErrorPresentation(
        message: "잘못된 관광지 정보예요.",
        recoveryAction: .none
    )

    private static let defaultPresentation = ErrorPresentation(
        message: "관광 상세 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
        recoveryAction: .retry
    )

    private static let authenticationPresentation = ErrorPresentation(
        message: "로그인 정보가 만료되었어요. 다시 로그인해 주세요.",
        recoveryAction: .signIn
    )
}
