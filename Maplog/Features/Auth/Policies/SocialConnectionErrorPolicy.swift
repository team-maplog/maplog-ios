import Foundation

enum SocialConnectionErrorPolicy {
    static func presentation(for error: Error) -> ErrorPresentation {
        if let apiError = error as? APIError {
            switch apiError {
            case .missingAccessToken:
                return ErrorPresentation(message: "다시 로그인해 주세요.", recoveryAction: .signIn)
            case let .server(_, response):
                let code = BackendErrorCode(serverCode: response.code)
                if code == .invalidAuthentication || code == .expiredAccessToken {
                    return ErrorPresentation(message: "다시 로그인해 주세요.", recoveryAction: .signIn)
                }
            default: break
            }
        }
        return ErrorPresentation(message: "연결 계정 정보를 불러오지 못했어요. 다시 시도해 주세요.", recoveryAction: .retry)
    }
}
