import Foundation

/// 릴스 목록과 단건 상세가 공통으로 쓰는 서버 응답을 앱 모델로 변환합니다.
enum LogResponseMapper {
    static func makeLogReel(
        from dto: LogReelDTO
    ) throws -> LogReel {
        LogReel(
            id: dto.logID,
            author: makeAuthor(from: dto.author),
            caption: dto.caption,
            address: dto.address,
            thumbnailURL: url(from: dto.thumbnailURL),
            playbackURL: url(from: dto.playbackURL),
            publishedAt: try publishedDate(from: dto.publishedAt),
            viewCount: dto.viewCount,
            clips: dto.clips
                .sorted { $0.displayOrder < $1.displayOrder }
                .map(makeClip),
            likeCount: dto.likeCount,
            commentCount: dto.commentCount,
            isLikedByViewer: dto.likedByViewer,
            isSavedByViewer: dto.savedByViewer
        )
    }

    static func makeLogDetail(
        from dto: LogDetailResponseDTO
    ) throws -> LogDetail {
        LogDetail(
            id: dto.logID,
            author: makeAuthor(from: dto.author),
            caption: dto.caption,
            address: dto.address,
            thumbnailURL: url(from: dto.thumbnailURL),
            playbackURL: url(from: dto.playbackURL),
            publishedAt: try publishedDate(from: dto.publishedAt),
            viewCount: dto.viewCount,
            clips: dto.clips
                .sorted { $0.displayOrder < $1.displayOrder }
                .map(makeClip),
            likeCount: dto.likeCount,
            commentCount: dto.commentCount,
            isLikedByViewer: dto.likedByViewer,
            isSavedByViewer: dto.savedByViewer
        )
    }

    private static func makeAuthor(
        from dto: LogReelAuthorDTO
    ) -> LogReelAuthor {
        LogReelAuthor(
            id: dto.userID,
            nickname: dto.nickname,
            profileImageURL: url(from: dto.profileImageURL)
        )
    }

    private static func makeClip(
        from dto: LogReelClipDTO
    ) -> LogReelClip {
        LogReelClip(
            id: dto.clipID,
            displayOrder: dto.displayOrder,
            startTimeMillis: dto.startTimeMillis,
            endTimeMillis: dto.endTimeMillis,
            location: LogReelLocation(
                name: normalizedText(dto.location.name),
                address: dto.location.address,
                latitude: dto.location.latitude,
                longitude: dto.location.longitude
            ),
            thumbnailURL: url(from: dto.thumbnailURL)
        )
    }

    private static func publishedDate(
        from value: String
    ) throws -> Date {
        if let date = fractionalISO8601Formatter.date(from: value) {
            return date
        }

        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }

        if let date = localDateTimeFormatter.date(from: value) {
            return date
        }

        throw LogResponseMappingError.invalidPublishedAt(value: value)
    }

    private static func url(
        from value: String?
    ) -> URL? {
        guard let value = normalizedText(value) else {
            return nil
        }

        if let absoluteURL = URL(string: value),
           absoluteURL.scheme != nil {
            return absoluteURL
        }

        return URL(
            string: value,
            relativeTo: APIConfiguration.baseURL
        )?.absoluteURL
    }

    private static func normalizedText(
        _ text: String?
    ) -> String? {
        guard let text else {
            return nil
        }

        let trimmedText = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmedText.isEmpty ? nil : trimmedText
    }

    private static let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter
    }()

    private static let localDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter
    }()
}

enum LogResponseMappingError: Error {
    case invalidPublishedAt(value: String)
}
