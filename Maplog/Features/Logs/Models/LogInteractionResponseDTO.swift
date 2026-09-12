import Foundation

struct LogLikeInteractionResponseDTO: Decodable {
    let logID: Int64
    let liked: Bool

    enum CodingKeys: String, CodingKey {
        case logID = "logId"
        case liked
    }
}

struct LogSaveInteractionResponseDTO: Decodable {
    let logID: Int64
    let saved: Bool

    enum CodingKeys: String, CodingKey {
        case logID = "logId"
        case saved
    }
}
