import Foundation

/// ViewModel이 JWT나 HTTP 응답을 몰라도 현재 앱 세션을 검증할 수 있게 하는 경계임
protocol SessionValidationRepository {
    func validateCurrentSession() async throws -> AuthenticatedSession
}
