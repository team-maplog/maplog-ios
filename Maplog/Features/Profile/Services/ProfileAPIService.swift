import Foundation

protocol ProfileAPIService {
    func fetchMyProfile() async throws -> MyProfileResponseDTO

    func fetchPublicProfile(
        nickname: String
    ) async throws -> PublicProfileResponseDTO

    func fetchMyLogs(
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPageDTO

    func fetchPublicProfileLogs(
        nickname: String,
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPageDTO

    func updateMyProfile(
        request: UpdateMyProfileRequestDTO
    ) async throws -> MyProfileResponseDTO

    func uploadProfileImage(
        imageData: Data
    ) async throws -> ProfileImageUploadResponseDTO

    func deleteMyProfile() async throws

    func fetchImageData(
        from url: URL,
        cacheKey: String,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data
}

extension ProfileAPIService {
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
