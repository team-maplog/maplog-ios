//
//  TourismErrorPolicy.swift
//  Maplog
//
//  Created by 한채림 on 7/23/26.
// 이 Policy는 외부 의존성이 없는 순수한 규칙이라 init으로 주입할 필요가 없음.
//APIClient, Repository처럼 교체 대상인 객체는 DI하고, 이런 순수 변환기는 static func로 두는 것이 오히려 자연스러움
//DI는 밖에서 교체할 가능성이 있는 도구를 주입받는 것이고, static func는 도구가 필요 없는 계산 규칙을 바로 호출하는 것
//TourismErrorPolicy에는 세 가지 책임만 있음
//APIError인지 확인
//서버의 문자열 코드를 BackendErrorCode로 바꿈
//관광 화면에 필요한 문구와 행동을 결정
//ViewModel       → 목록을 처음부터 다시 불러올지 결정
//TourismErrorPolicy → CURSOR-001인지 판별
//BackendErrorCode → 서버 문자열을 Swift enum으로 변환

enum TourismErrorPolicy {
    static func isCursorInvalid(_ error: Error) -> Bool {
        guard case let APIError.server(_, response) = error else {
            return false
        }

        return BackendErrorCode(serverCode: response.code) == .cursorInvalid
    }


    static func presentation(for error: Error) -> ErrorPresentation {
        if case TourismRepositoryError.requestInvalidated = error {
            return ErrorPresentation(message: "축제 정보를 다시 불러와 주세요.", recoveryAction: .retry)
        }
        guard let apiError = error as? APIError else {
            return defaultPresentation
        }

        switch apiError {
        case .network:
            return ErrorPresentation(
                message: "인터넷 연결을 확인한 뒤 다시 시도해 주세요.",
                recoveryAction: .retry)

        case .server(let statusCode, let response):
            let errorCode = BackendErrorCode(serverCode: response.code)

            return serverErrorPresentation(
                for: errorCode,
                statusCode: statusCode)

        case .missingAccessToken:
            return authenticationPresentation

        default:
            return defaultPresentation
        }
    }

    private static func serverErrorPresentation(
        for errorCode: BackendErrorCode,
        statusCode: Int) -> ErrorPresentation {
            switch errorCode {
            case .tourAPIUnavailable:
                return ErrorPresentation(
                    message: "현재 축제 정보를 이용할 수 없어요.",
                    recoveryAction: .none)

            case .tourAPIRequestFailed:
                return ErrorPresentation(
                    message: "축제 정보를 불러오는 중 문제가 생겼어요. 잠시 후 다시 시도해 주세요.",
                    recoveryAction: .retry)

            case .unknown:
                if (500...599).contains(statusCode) {
                    return ErrorPresentation(
                        message: "축제 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
                        recoveryAction: .retry)
                }
                return defaultPresentation

            case .expiredAccessToken, .invalidAuthentication:
                return authenticationPresentation

            default:
                return defaultPresentation
            }
        }

    private static let defaultPresentation = ErrorPresentation(
        message: "축제 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
        recoveryAction: .none)

    private static let authenticationPresentation = ErrorPresentation(
        message: "로그인 정보가 만료되었어요. 다시 로그인해 주세요.",
        recoveryAction: .signIn)

}
