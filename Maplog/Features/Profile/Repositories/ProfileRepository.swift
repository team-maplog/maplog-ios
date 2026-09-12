import Foundation

protocol ProfileRepository {
    func fetchMyProfile() async throws -> MyProfile

    func fetchPublicProfile(
        nickname: String
    ) async throws -> PublicProfile

    func fetchMyLogs(
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPage

    func fetchPublicProfileLogs(
        nickname: String,
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPage

    func updateMyProfile(
        _ update: ProfileUpdate
    ) async throws -> MyProfile

    func deleteMyProfile() async throws

    func fetchImageData(
        from url: URL,
        cacheKey: String,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data
}

extension ProfileRepository {
    func fetchImageData(
        from url: URL
    ) async throws -> Data {
        try await fetchImageData(
            from: url,
            cacheKey: MaplogImageCacheKey.stableURL(url),
            targetSize: .profileAvatar
        )
    }
}
