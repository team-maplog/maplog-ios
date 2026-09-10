import Foundation

final class DefaultSocialConnectionRepository: SocialConnectionRepository {
    private let apiService: any SocialConnectionAPIService

    init(apiService: any SocialConnectionAPIService) {
        self.apiService = apiService
    }

    func fetchConnections() async throws -> [SocialConnection] {
        let response = try await apiService.fetchConnections()
        return response.map {
            SocialConnection(
                provider: $0.provider.lowercased(), isConnected: $0.connected,
                createdAt: $0.createdAt, updatedAt: $0.updatedAt
            )
        }
    }
}
