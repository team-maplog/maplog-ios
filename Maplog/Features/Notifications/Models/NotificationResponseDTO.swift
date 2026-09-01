import Foundation

/// 알림 API의 JSON 전용 모델입니다. 서버가 목록을 `items` 또는 `notifications`로
/// 내려주는 경우를 모두 수용해, View·Repository가 JSON 키에 의존하지 않게 합니다.
struct NotificationPageDTO: Decodable {
    let notifications: [NotificationDTO]
    let hasNext: Bool
    let nextCursor: String?

    init(from decoder: Decoder) throws {
        if var unkeyedContainer = try? decoder.unkeyedContainer() {
            var decodedNotifications: [NotificationDTO] = []
            while !unkeyedContainer.isAtEnd {
                decodedNotifications.append(
                    try unkeyedContainer.decode(NotificationDTO.self)
                )
            }

            notifications = decodedNotifications
            hasNext = false
            nextCursor = nil
            return
        }

        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        notifications = container.decodeFirst(
            ["notifications", "items", "content"],
            as: [NotificationDTO].self
        ) ?? []
        nextCursor = container.decodeFlexibleString(
            forAnyOf: ["nextCursor", "cursor"]
        )
        hasNext = container.decodeFlexibleBool(
            forAnyOf: ["hasNext", "hasMore"]
        ) ?? (nextCursor != nil)
    }
}

struct NotificationDTO: Decodable {
    let id: String
    let type: String
    let title: String?
    let message: String?
    let actor: NotificationActorDTO?
    let logID: Int64?
    let commentID: Int64?
    let isRead: Bool
    let createdAt: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)

        id = container.decodeFlexibleString(
            forAnyOf: ["notificationId", "id"]
        ) ?? UUID().uuidString
        type = container.decodeFlexibleString(forAnyOf: ["type"]) ?? "UNKNOWN"
        title = container.decodeFlexibleString(forAnyOf: ["title"])
        message = container.decodeFlexibleString(
            forAnyOf: ["message", "content", "body"]
        )

        let decodedActor = container.decodeFirst(
            ["actor", "sender", "actorUser"],
            as: NotificationActorDTO.self
        )
        actor = decodedActor ?? NotificationActorDTO(
            id: container.decodeUUID(forAnyOf: ["actorUserId", "userId"]),
            nickname: container.decodeFlexibleString(
                forAnyOf: ["actorNickname", "nickname", "senderNickname"]
            ),
            profileImageURL: container.decodeFlexibleString(
                forAnyOf: ["actorProfileImageUrl", "profileImageUrl"]
            )
        )

        logID = container.decodeInt64(forAnyOf: ["logId"])
        commentID = container.decodeInt64(forAnyOf: ["commentId"])
        isRead = container.decodeFlexibleBool(forAnyOf: ["isRead", "read"]) ?? false
        createdAt = container.decodeFlexibleString(forAnyOf: ["createdAt", "sentAt"])
    }
}

struct NotificationActorDTO: Decodable {
    let id: UUID?
    let nickname: String?
    let profileImageURL: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        id = container.decodeUUID(forAnyOf: ["userId", "id", "actorUserId"])
        nickname = container.decodeFlexibleString(forAnyOf: ["nickname", "name"])
        profileImageURL = container.decodeFlexibleString(
            forAnyOf: ["profileImageUrl", "imageUrl"]
        )
    }

    init(id: UUID?, nickname: String?, profileImageURL: String?) {
        self.id = id
        self.nickname = nickname
        self.profileImageURL = profileImageURL
    }
}

private struct FlexibleCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }

    init(_ value: String) {
        stringValue = value
        intValue = nil
    }
}

private extension KeyedDecodingContainer where Key == FlexibleCodingKey {
    func decodeFirst<Value: Decodable>(
        _ keys: [String],
        as type: Value.Type
    ) -> Value? {
        for key in keys {
            let codingKey = FlexibleCodingKey(key)
            if contains(codingKey), let value = try? decode(Value.self, forKey: codingKey) {
                return value
            }
        }
        return nil
    }

    func decodeFlexibleString(forAnyOf keys: [String]) -> String? {
        for key in keys {
            let codingKey = FlexibleCodingKey(key)
            if contains(codingKey),
               let value = try? decode(String.self, forKey: codingKey),
               !value.isEmpty {
                return value
            }
            if contains(codingKey), let value = try? decode(Int64.self, forKey: codingKey) {
                return String(value)
            }
        }
        return nil
    }

    func decodeInt64(forAnyOf keys: [String]) -> Int64? {
        for key in keys {
            let codingKey = FlexibleCodingKey(key)
            if contains(codingKey), let value = try? decode(Int64.self, forKey: codingKey) {
                return value
            }
            if contains(codingKey),
               let value = try? decode(String.self, forKey: codingKey),
               let number = Int64(value) {
                return number
            }
        }
        return nil
    }

    func decodeUUID(forAnyOf keys: [String]) -> UUID? {
        guard let value = decodeFlexibleString(forAnyOf: keys) else {
            return nil
        }
        return UUID(uuidString: value)
    }

    func decodeFlexibleBool(forAnyOf keys: [String]) -> Bool? {
        for key in keys {
            let codingKey = FlexibleCodingKey(key)
            if contains(codingKey), let value = try? decode(Bool.self, forKey: codingKey) {
                return value
            }
            if contains(codingKey), let value = try? decode(String.self, forKey: codingKey) {
                switch value.lowercased() {
                case "true", "1":
                    return true
                case "false", "0":
                    return false
                default:
                    continue
                }
            }
        }
        return nil
    }
}
