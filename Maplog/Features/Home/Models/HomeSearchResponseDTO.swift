import Foundation

// 홈 통합 검색 API의 서버 응답 전용 타입입니다. View나 Domain Model에서 JSON 키를 알 필요가 없게 합니다.
struct HomeSearchPageDTO: Decodable {
    let query: String
    let scope: String
    let totalCount: Int64?
    let hasNext: Bool
    let nextCursor: String?
    let items: [HomeSearchItemDTO]
}

struct HomeSearchItemDTO: Decodable {
    let type: String
    let id: Int64
    let title: String
    let subtitle: String
    let thumbnailURL: String?
    let publishedAt: String?
    let author: HomeSearchAuthorDTO?
    let likeCount: Int64?
    let commentCount: Int64?
    let category: String?
    let startDate: String?
    let endDate: String?

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case title
        case subtitle
        case thumbnailURL = "thumbnailUrl"
        case publishedAt
        case author
        case likeCount
        case commentCount
        case category
        case startDate
        case endDate
    }
}

struct HomeSearchAuthorDTO: Decodable {
    let userID: UUID
    let nickname: String
    let profileImageURL: String?

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case nickname
        case profileImageURL = "profileImageUrl"
    }
}
