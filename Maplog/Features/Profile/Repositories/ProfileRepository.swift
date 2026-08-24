import Foundation

protocol ProfileRepository {
    func fetchMyProfile() async throws -> MyProfile

    func fetchMyLogs(
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPage

    func updateMyProfile(
        _ update: ProfileUpdate
    ) async throws -> MyProfile

    func deleteMyProfile() async throws

    func fetchImageData(
        from url: URL
    ) async throws -> Data
}
