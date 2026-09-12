import Foundation

enum HomeSearchScope: String, CaseIterable, Identifiable, Sendable {
    case all = "ALL"
    case log = "LOG"
    case tourism = "TOURISM"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "전체"
        case .log:
            return "맵로그"
        case .tourism:
            return "관광"
        }
    }
}

enum HomeSearchSort: String, Sendable {
    case relevance = "RELEVANCE"
    case latest = "LATEST"
}

struct HomeSearchRequest: Equatable, Sendable {
    let query: String
    let scope: HomeSearchScope
    let cursor: String?
    let size: Int
    let sort: HomeSearchSort
}

struct HomeSearchPage: Equatable, Sendable {
    let query: String
    let scope: HomeSearchScope
    let totalCount: Int?
    let items: [HomeSearchItem]
    let hasNext: Bool
    let nextCursor: String?
}

struct HomeSearchItem: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case log = "LOG"
        case tourism = "TOURISM"
    }

    let kind: Kind
    let serverID: Int64
    let title: String
    let subtitle: String
    let thumbnailURL: URL?
    let publishedAt: Date?
    let author: HomeSearchAuthor?
    let likeCount: Int64?
    let commentCount: Int64?
    let category: String?
    let startDate: Date?
    let endDate: Date?

    // LOG와 TOURISM은 서로 다른 서버 영역의 ID를 쓰므로, 화면 식별자에는 타입도 함께 넣습니다.
    var id: String {
        "\(kind.rawValue)-\(serverID)"
    }
}

struct HomeSearchAuthor: Equatable, Sendable {
    let id: UUID
    let nickname: String
    let profileImageURL: URL?
}
