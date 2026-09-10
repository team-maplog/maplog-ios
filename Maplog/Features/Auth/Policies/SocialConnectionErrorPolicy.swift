import Foundation

enum SocialConnectionErrorPolicy {
    static func disconnectPresentation(for error: Error) -> ErrorPresentation {
        if case let APIError.server(_, response) = error {
            switch BackendErrorCode(serverCode: response.code) {
            case .oauthPrimaryConnectionRequired:
                return ErrorPresentation(message: "마지막 로그인 방법은 해제할 수 없어요. 계정을 삭제하려면 설정에서 회원 탈퇴를 이용해 주세요.", recoveryAction: .none)
            case .oauthConnectionNotFound:
                return ErrorPresentation(message: "이미 해제되었거나 연결 정보를 찾을 수 없어요. 목록을 새로고침해 주세요.", recoveryAction: .retry)
            case .oauthRevokeFailed:
                return ErrorPresentation(message: "소셜 제공자에서 연결을 해제하지 못했어요. 잠시 후 다시 시도해 주세요.", recoveryAction: .retry)
            default: break
            }
        }
        let presentation = presentation(for: error)
        if presentation.recoveryAction == .signIn { return presentation }
        return ErrorPresentation(message: "연결 해제 결과를 확인하지 못했어요. 목록을 새로고침한 뒤 다시 시도해 주세요.", recoveryAction: .retry)
    }

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
