import Foundation

final class DefaultFollowRepository: FollowRepository {
    private let apiService: any FollowAPIService

    init(
        apiService: any FollowAPIService
    ) {
        self.apiService = apiService
    }

    func fetchUsers(
        kind: FollowListKind,
        cursor: String?,
        size: Int
    ) async throws -> FollowUserPage {
        let pageDTO = try await apiService.fetchUsers(
            kind: kind,
            cursor: cursor,
            size: size
        )

        return FollowUserPage(
            users: pageDTO.content.map(makeFollowUser),
            hasNext: pageDTO.hasNext,
            nextCursor: normalizedCursor(pageDTO.nextCursor)
        )
    }

    func isFollowing(
        userID: UUID
    ) async throws -> Bool {
        var cursor: String?

        while true {
            try Task.checkCancellation()

            let page = try await fetchUsers(
                kind: .following,
                cursor: cursor,
                size: 100
            )

            if page.users.contains(where: { $0.id == userID }) {
                return true
            }

            guard page.hasNext else {
                return false
            }

            guard let nextCursor = page.nextCursor else {
                throw APIError.invalidResponse
            }

            cursor = nextCursor
        }
    }

    func setFollowing(
        userID: UUID,
        isFollowing: Bool
    ) async throws -> FollowState {
        let response = try await apiService.setFollowing(
            userID: userID,
            isFollowing: isFollowing
        )

        guard response.followingUserID == userID else {
            throw APIError.invalidResponse
        }

        return FollowState(
            userID: response.followingUserID,
            isFollowing: response.following
        )
    }

    private func makeFollowUser(
        from dto: FollowUserSummaryDTO
    ) -> FollowUser {
        FollowUser(
            id: dto.userID,
            nickname: dto.nickname,
            profileImageURL: url(from: dto.profileImageURL)
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

    private func normalizedCursor(
        _ cursor: String?
    ) -> String? {
        normalizedText(cursor)
    }

    private func normalizedText(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
