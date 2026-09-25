import Foundation

final class DefaultSocialConnectionRepository: SocialConnectionRepository {
    private let apiService: any SocialConnectionAPIService

    init(apiService: any SocialConnectionAPIService) {
        self.apiService = apiService
    }

    func disconnect(provider: String) async throws {
        let response = try await apiService.disconnect(provider: provider)
        guard response.provider.lowercased() == provider, !response.connected else {
            throw APIError.invalidResponse
        }
    }

    func connectionRedirectURL(provider: String) async throws -> URL {
        let response = try await apiService.fetchConnectionRedirect(provider: provider)
        guard response.registrationID.lowercased() == provider,
              let url = URL(string: response.redirectURL),
              url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else {
            throw OAuthRepositoryError.invalidRedirectURL
        }
        return url
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
