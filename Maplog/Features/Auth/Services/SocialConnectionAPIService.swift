import Foundation

protocol SocialConnectionAPIService {
    func fetchConnectionRedirect(provider: String) async throws -> OAuthRedirectResponseDTO

    func disconnect(provider: String) async throws -> SocialConnectionResponseDTO

    func fetchConnections() async throws -> [SocialConnectionResponseDTO]
}
