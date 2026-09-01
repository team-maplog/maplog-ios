import Foundation

/// 인증 요청을 보낼 수 있는지 판단하는 최소 역할입니다.
/// FCM 동기화는 구체적인 `AuthSessionStore`가 아니라 이 역할에만 의존합니다.
@MainActor
protocol AuthenticationStateProviding: AnyObject {
    var isAuthenticated: Bool { get }
}
