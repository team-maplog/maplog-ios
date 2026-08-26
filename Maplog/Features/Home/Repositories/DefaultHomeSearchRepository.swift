import Foundation

enum HomeSearchRepositoryError: Error, Equatable {
    case invalidScope(String)
    case invalidItemType(String)
}

final class DefaultHomeSearchRepository: HomeSearchRepository {
    private let apiService: any HomeSearchAPIService

    init(apiService: any HomeSearchAPIService) {
        self.apiService = apiService
    }

    func search(
        request: HomeSearchRequest
    ) async throws -> HomeSearchPage {
        let pageDTO = try await apiService.search(request: request)

        guard let scope = HomeSearchScope(rawValue: pageDTO.scope) else {
            throw HomeSearchRepositoryError.invalidScope(pageDTO.scope)
        }

        let items = try pageDTO.items.map(makeItem)

        return HomeSearchPage(
            query: pageDTO.query,
            scope: scope,
            totalCount: pageDTO.totalCount.map(Int.init),
            items: items,
            hasNext: pageDTO.hasNext,
            nextCursor: pageDTO.nextCursor
        )
    }

    private func makeItem(
        from dto: HomeSearchItemDTO
    ) throws -> HomeSearchItem {
        guard let kind = HomeSearchItem.Kind(rawValue: dto.type) else {
            throw HomeSearchRepositoryError.invalidItemType(dto.type)
        }

        return HomeSearchItem(
            kind: kind,
            serverID: dto.id,
            title: dto.title,
            subtitle: dto.subtitle,
            thumbnailURL: makeURL(from: dto.thumbnailURL),
            publishedAt: dateTime(from: dto.publishedAt),
            author: dto.author.map(makeAuthor),
            likeCount: dto.likeCount,
            commentCount: dto.commentCount,
            category: dto.category,
            startDate: date(from: dto.startDate),
            endDate: date(from: dto.endDate)
        )
    }

    private func makeAuthor(
        from dto: HomeSearchAuthorDTO
    ) -> HomeSearchAuthor {
        HomeSearchAuthor(
            id: dto.userID,
            nickname: dto.nickname,
            profileImageURL: makeURL(from: dto.profileImageURL)
        )
    }

    private func makeURL(from value: String?) -> URL? {
        guard let value,
              !value.isEmpty
        else {
            return nil
        }

        if let absoluteURL = URL(string: value),
           absoluteURL.scheme != nil {
            return absoluteURL
        }

        return APIConfiguration.baseURL.appendingPathComponent(
            value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        )
    }

    private func dateTime(from value: String?) -> Date? {
        guard let value else {
            return nil
        }

        for formatter in dateTimeFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private func date(from value: String?) -> Date? {
        guard let value else {
            return nil
        }

        return dateFormatter.date(from: value)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

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
