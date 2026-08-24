import Foundation

final class DefaultProfileRepository: ProfileRepository {
    private let apiService: any ProfileAPIService

    init(
        apiService: any ProfileAPIService
    ) {
        self.apiService = apiService
    }

    func fetchMyProfile() async throws -> MyProfile {
        let dto = try await apiService.fetchMyProfile()

        return makeMyProfile(from: dto)
    }

    func fetchMyLogs(
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPage {
        let pageDTO = try await apiService.fetchMyLogs(
            cursor: cursor,
            size: size
        )

        let logs = try pageDTO.content.map(
            makeProfileLog
        )

        return ProfileLogPage(
            logs: logs,
            hasNext: pageDTO.hasNext,
            nextCursor: pageDTO.nextCursor
        )
    }

    func updateMyProfile(
        _ update: ProfileUpdate
    ) async throws -> MyProfile {
        let profileImageFileID: Int64?

        if let newProfileImageData = update.newProfileImageData {
            let imageUpload = try await apiService.uploadProfileImage(
                imageData: newProfileImageData
            )
            profileImageFileID = imageUpload.fileID
        } else {
            profileImageFileID = nil
        }

        let response = try await apiService.updateMyProfile(
            request: UpdateMyProfileRequestDTO(
                nickname: update.nickname,
                profileImageFileID: profileImageFileID,
                bio: update.bio
            )
        )

        return makeMyProfile(from: response)
    }

    func deleteMyProfile() async throws {
        try await apiService.deleteMyProfile()
    }

    func fetchImageData(
        from url: URL
    ) async throws -> Data {
        try await apiService.fetchImageData(
            from: url
        )
    }

    private func makeMyProfile(
        from dto: MyProfileResponseDTO
    ) -> MyProfile {
        MyProfile(
            id: dto.userID,
            nickname: dto.nickname,
            profileImageURL: url(from: dto.profileImageURL),
            bio: dto.bio ?? "",
            followerCount: dto.followerCount,
            followingCount: dto.followingCount,
            logCount: dto.logCount
        )
    }

    private func makeProfileLog(
        from dto: ProfileLogResponseDTO
    ) throws -> ProfileLog {
        guard dto.videoDurationMillis >= 0,
              dto.viewCount >= 0 else {
            throw ProfileRepositoryError.invalidLogMetadata(
                logID: dto.logID
            )
        }

        return ProfileLog(
            id: dto.logID,
            thumbnailURL: url(from: dto.thumbnailURL),
            address: dto.address,
            videoDurationMillis: dto.videoDurationMillis,
            viewCount: dto.viewCount,
            createdAt: try date(from: dto.createdAt)
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

    private func date(
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

        throw ProfileRepositoryError.invalidCreatedAt(
            value: value
        )
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

enum ProfileRepositoryError: Error, Equatable {
    case invalidCreatedAt(value: String)
    case invalidLogMetadata(logID: Int64)
}
