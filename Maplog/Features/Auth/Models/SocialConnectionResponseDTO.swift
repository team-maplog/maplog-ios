import Foundation

struct SocialConnectionResponseDTO: Decodable {
    let provider: String
    let connected: Bool
    let createdAt: String?
    let updatedAt: String?
}
