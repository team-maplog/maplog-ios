import Foundation

/// JWT를 받은 뒤 실제 보호 API까지 통과했을 때만 앱 세션을 활성화하는 역할임
@MainActor
protocol AuthSessionLifecycleManaging: AnyObject {
    func establishSession(with token: AuthToken) async throws
    func validateRestoredSession() async -> Bool
}
