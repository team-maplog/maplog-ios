import Foundation

protocol SocialConnectionAPIService {
    func fetchConnections() async throws -> [SocialConnectionResponseDTO]
}
