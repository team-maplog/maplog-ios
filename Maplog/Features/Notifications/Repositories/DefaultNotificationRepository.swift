import Foundation

final class DefaultNotificationRepository: NotificationRepository {
    private let apiService: any NotificationAPIService

    init(apiService: any NotificationAPIService) {
        self.apiService = apiService
    }

    func registerFCMToken(
        _ registration: FCMTokenRegistration
    ) async throws {
        try await apiService.registerFCMToken(registration)
    }

    func unregisterFCMToken(deviceID: String) async throws {
        try await apiService.unregisterFCMToken(deviceID: deviceID)
    }

    func fetchNotifications(
        cursor: String?,
        size: Int
    ) async throws -> MaplogNotificationPage {
        let pageDTO = try await apiService.fetchNotifications(
            cursor: cursor,
            size: size
        )

        return MaplogNotificationPage(
            notifications: pageDTO.notifications.map(makeNotification),
            hasNext: pageDTO.hasNext,
            nextCursor: pageDTO.nextCursor
        )
    }

    private func makeNotification(
        from dto: NotificationDTO
    ) -> MaplogNotification {
        let kind = MaplogNotificationKind(serverValue: dto.type)
        let actor = dto.actor.map(makeActor)

        return MaplogNotification(
            id: dto.id,
            kind: kind,
            title: displayTitle(
                preferredTitle: dto.title,
                kind: kind,
                actorNickname: actor?.nickname
            ),
            message: dto.message ?? defaultMessage(for: kind),
            actor: actor,
            createdAt: dateTime(from: dto.createdAt),
            isRead: dto.isRead,
            destination: destination(
                kind: kind,
                logID: dto.logID,
                commentID: dto.commentID,
                actorID: actor?.id
            )
        )
    }

    private func makeActor(
        from dto: NotificationActorDTO
    ) -> MaplogNotificationActor {
        MaplogNotificationActor(
            id: dto.id,
            nickname: dto.nickname,
            profileImageURL: url(from: dto.profileImageURL)
        )
    }

    private func destination(
        kind: MaplogNotificationKind,
        logID: Int64?,
        commentID: Int64?,
        actorID: UUID?
    ) -> MaplogNotificationDestination {
        if let logID {
            return .logDetail(logID: logID, commentID: commentID)
        }

        if case .follow = kind, let actorID {
            return .userProfile(userID: actorID)
        }

        return .inbox
    }

    private func displayTitle(
        preferredTitle: String?,
        kind: MaplogNotificationKind,
        actorNickname: String?
    ) -> String {
        if let preferredTitle,
           !preferredTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return preferredTitle
        }

        let actor = actorNickname ?? "누군가"
        switch kind {
        case .logLike:
            return "\(actor)님이 회원님의 로그를 좋아합니다."
        case .comment:
            return "\(actor)님이 회원님의 로그에 댓글을 남겼습니다."
        case .commentReply:
            return "\(actor)님이 회원님의 댓글에 답글을 남겼습니다."
        case .commentLike:
            return "\(actor)님이 회원님의 댓글을 좋아합니다."
        case .follow:
            return "\(actor)님이 회원님을 팔로우했습니다."
        case .unknown:
            return "새로운 알림이 도착했어요."
        }
    }

    private func defaultMessage(
        for kind: MaplogNotificationKind
    ) -> String {
        switch kind {
        case .logLike, .commentLike:
            return "좋아요를 확인해 보세요."
        case .comment, .commentReply:
            return "댓글 내용을 확인해 보세요."
        case .follow:
            return "새로운 팔로워가 생겼어요."
        case .unknown:
            return "알림을 확인해 보세요."
        }
    }

    private func url(from value: String?) -> URL? {
        guard let value,
              !value.isEmpty
        else {
            return nil
        }

        if let url = URL(string: value), url.scheme != nil {
            return url
        }

        return APIConfiguration.baseURL.appendingPathComponent(
            value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        )
    }

    private func dateTime(from value: String?) -> Date? {
        guard let value else {
            return nil
        }

        for formatter in dateTimeFormatters where formatter.date(from: value) != nil {
            return formatter.date(from: value)
        }

        return nil
    }

    private let dateTimeFormatters: [ISO8601DateFormatter] = {
        let fractionalSeconds = ISO8601DateFormatter()
        fractionalSeconds.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]

        return [fractionalSeconds, standard]
    }()
}
