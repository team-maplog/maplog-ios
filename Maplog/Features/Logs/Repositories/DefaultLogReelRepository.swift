//
//  DefaultLogReelRepository.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// 서버 DTO를 앱 모델로 번역

import Foundation

final class DefaultLogReelRepository: LogReelRepository {
    private let apiService: any LogReelAPIService

    init(
        apiService: any LogReelAPIService
    ) {
        self.apiService = apiService
    }

    func fetchReels(
        cursor: String?,
        size: Int
    ) async throws -> LogReelPage {
        let pageDTO = try await apiService.fetchReels(
            cursor: cursor,
            size: size
        )

        let reels = try pageDTO.content.map(
            makeLogReel
        )

        return LogReelPage(
            reels: reels,
            hasNext: pageDTO.hasNext,
            nextCursor: pageDTO.nextCursor
        )
    }

    private func makeLogReel(
        from dto: LogReelDTO
    ) throws -> LogReel {
        LogReel(
            id: dto.logID,
            author: LogReelAuthor(
                id: dto.author.userID,
                nickname: dto.author.nickname,
                profileImageURL: url(from: dto.author.profileImageURL)
            ),
            caption: dto.caption,
            address: dto.address,
            thumbnailURL: url(from: dto.thumbnailURL),
            playbackURL: url(from: dto.playbackURL),
            publishedAt: try publishedDate(
                from: dto.publishedAt
            ),
            viewCount: dto.viewCount,
            clips: dto.clips
                .sorted { $0.displayOrder < $1.displayOrder } // 지도에서 클립별 장소 순서대로 보여줌
                .map(makeLogReelClip),
            likeCount: dto.likeCount,
            commentCount: dto.commentCount,
            isLikedByViewer: dto.likedByViewer,
            isSavedByViewer: dto.savedByViewer
        )
    }

    private func makeLogReelClip(
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

    private func publishedDate(
        from value: String
    ) throws -> Date {
        if let date = fractionalISO8601Formatter.date(
            from: value
        ) {
            return date
        }

        if let date = ISO8601DateFormatter().date(
            from: value
        ) {
            return date
        }

        if let date = localDateTimeFormatter.date(
            from: value
        ) {
            return date
        }

        throw LogReelRepositoryError.invalidPublishedAt(
            value: value
        )
    }

    private func url(
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

    private func normalizedText(
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

    private let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter
    }()

    private let localDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()

        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"

        return formatter
    }()
}

enum LogReelRepositoryError: Error {
    case invalidPublishedAt(value: String)
}
