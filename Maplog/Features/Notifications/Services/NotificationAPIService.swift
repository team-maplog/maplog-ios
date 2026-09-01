import Foundation

protocol NotificationAPIService {
    func registerFCMToken(_ registration: FCMTokenRegistration) async throws
    func unregisterFCMToken(deviceID: String) async throws
    func fetchNotifications(
        cursor: String?,
        size: Int
    ) async throws -> NotificationPageDTO
}
