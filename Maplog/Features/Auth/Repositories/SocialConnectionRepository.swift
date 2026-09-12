import Foundation

protocol SocialConnectionRepository {
    func disconnect(provider: String) async throws

    func fetchConnections() async throws -> [SocialConnection]
}
