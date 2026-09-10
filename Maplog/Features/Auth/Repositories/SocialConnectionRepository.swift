import Foundation

protocol SocialConnectionRepository {
    func fetchConnections() async throws -> [SocialConnection]
}
