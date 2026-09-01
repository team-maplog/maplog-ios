import Foundation

final class DefaultSessionValidationRepository: SessionValidationRepository {
    private let apiService: any SessionValidationAPIService

    init(apiService: any SessionValidationAPIService) {
        self.apiService = apiService
    }

    func validateCurrentSession() async throws -> AuthenticatedSession {
        let response = try await apiService.validateCurrentSession()
        return AuthenticatedSession(userID: response.userID)
    }
}
