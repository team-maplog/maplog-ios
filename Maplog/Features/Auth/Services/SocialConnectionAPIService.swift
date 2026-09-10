import Foundation

protocol SocialConnectionAPIService {
    func disconnect(provider: String) async throws -> SocialConnectionResponseDTO

    func fetchConnections() async throws -> [SocialConnectionResponseDTO]
}
