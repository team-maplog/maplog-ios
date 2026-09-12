import Foundation

protocol NotificationRepository {
    func registerFCMToken(_ registration: FCMTokenRegistration) async throws
    func unregisterFCMToken(deviceID: String) async throws
    func fetchNotifications(
        cursor: String?,
        size: Int
    ) async throws -> MaplogNotificationPage
}
