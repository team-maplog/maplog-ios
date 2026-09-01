import Foundation

enum MaplogNotificationKind: Equatable, Sendable {
    case logLike
    case comment
    case commentReply
    case commentLike
    case follow
    case unknown(String)

    init(serverValue: String) {
        switch serverValue {
        case "LOG_LIKE":
            self = .logLike
        case "COMMENT":
            self = .comment
        case "COMMENT_REPLY":
            self = .commentReply
        case "COMMENT_LIKE":
            self = .commentLike
        case "FOLLOW":
            self = .follow
        default:
            self = .unknown(serverValue)
        }
    }

    var symbolName: String {
        switch self {
        case .logLike, .commentLike:
            return "heart.fill"
        case .comment, .commentReply:
            return "bubble.left.fill"
        case .follow:
            return "person.badge.plus"
        case .unknown:
            return "bell.fill"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .logLike:
            return "로그 좋아요"
        case .comment:
            return "댓글"
        case .commentReply:
            return "댓글 답글"
        case .commentLike:
            return "댓글 좋아요"
        case .follow:
            return "팔로우"
        case .unknown:
            return "알림"
        }
    }
}

enum MaplogNotificationDestination: Equatable, Sendable {
    case logDetail(logID: Int64, commentID: Int64?)
    case userProfile(userID: UUID)
    case inbox
}

struct MaplogNotificationActor: Equatable, Sendable {
    let id: UUID?
    let nickname: String?
    let profileImageURL: URL?
}

struct MaplogNotification: Identifiable, Equatable, Sendable {
    let id: String
    let kind: MaplogNotificationKind
    let title: String
    let message: String
    let actor: MaplogNotificationActor?
    let createdAt: Date?
    let isRead: Bool
    let destination: MaplogNotificationDestination
}

struct MaplogNotificationPage: Equatable, Sendable {
    let notifications: [MaplogNotification]
    let hasNext: Bool
    let nextCursor: String?
}

struct FCMTokenRegistration: Equatable, Sendable {
    let deviceID: String
    let fcmToken: String
}
