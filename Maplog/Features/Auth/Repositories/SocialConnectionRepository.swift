import Foundation

protocol SocialConnectionRepository {
    func connectionRedirectURL(provider: String) async throws -> URL

    func disconnect(provider: String) async throws

    func fetchConnections() async throws -> [SocialConnection]
}
