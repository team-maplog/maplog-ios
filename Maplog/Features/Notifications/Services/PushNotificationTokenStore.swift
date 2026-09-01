import Foundation

protocol PushNotificationTokenStoring {
    func deviceID() throws -> String
    func fcmToken() throws -> String?
    func saveFCMToken(_ token: String) throws
    func removeFCMToken() throws
}

final class KeychainPushNotificationTokenStore: PushNotificationTokenStoring {
    private enum Key {
        static let deviceID = "maplog.push.deviceID"
        static let fcmToken = "maplog.push.fcmToken"
    }

    func deviceID() throws -> String {
        if let storedID = try KeychainService.read(for: Key.deviceID),
           !storedID.isEmpty {
            return storedID
        }

        let newID = UUID().uuidString.lowercased()
        try KeychainService.save(newID, for: Key.deviceID)
        return newID
    }

    func fcmToken() throws -> String? {
        try KeychainService.read(for: Key.fcmToken)
    }

    func saveFCMToken(_ token: String) throws {
        try KeychainService.save(token, for: Key.fcmToken)
    }

    func removeFCMToken() throws {
        try KeychainService.delete(for: Key.fcmToken)
    }
}
