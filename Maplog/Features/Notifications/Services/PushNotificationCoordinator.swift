import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationCoordinator: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let notificationRepository: any NotificationRepository
    private let authenticationState: any AuthenticationStateProviding
    private let tokenStore: any PushNotificationTokenStoring
    private let onNavigate: (MaplogNotificationDestination) -> Void

    init(
        notificationRepository: any NotificationRepository,
        authenticationState: any AuthenticationStateProviding,
        tokenStore: any PushNotificationTokenStoring,
        onNavigate: @escaping (MaplogNotificationDestination) -> Void
    ) {
        self.notificationRepository = notificationRepository
        self.authenticationState = authenticationState
        self.tokenStore = tokenStore
        self.onNavigate = onNavigate
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await UNUserNotificationCenter.current()
            .notificationSettings()
            .authorizationStatus
    }

    /// 권한은 앱 실행 직후가 아니라 사용자가 알림 목록을 열었을 때 요청합니다.
    func requestPermissionIfNeeded() async {
        await refreshAuthorizationStatus()

        guard authorizationStatus == .notDetermined else {
            if authorizationStatus == .authorized || authorizationStatus == .provisional {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return
        }

        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()

            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            await refreshAuthorizationStatus()
        }
    }

    func receiveFCMRegistrationToken(_ token: String) async {
        guard !token.isEmpty else {
            return
        }

        do {
            try tokenStore.saveFCMToken(token)
        } catch {
            return
        }

        await syncCachedTokenIfAuthenticated()
    }

    func syncCachedTokenIfAuthenticated() async {
        guard authenticationState.isAuthenticated else {
            return
        }

        do {
            guard let fcmToken = try tokenStore.fcmToken(), !fcmToken.isEmpty else {
                return
            }

            let registration = FCMTokenRegistration(
                deviceID: try tokenStore.deviceID(),
                fcmToken: fcmToken
            )
            try await notificationRepository.registerFCMToken(registration)
        } catch {
            // 네트워크 실패 시 Keychain의 token을 남겨 두고 다음 로그인·foreground에서 재시도합니다.
        }
    }

    func unregisterCurrentDevice() async {
        guard authenticationState.isAuthenticated else {
            return
        }

        do {
            let deviceID = try tokenStore.deviceID()
            try await notificationRepository.unregisterFCMToken(deviceID: deviceID)
            try tokenStore.removeFCMToken()
        } catch {
            // 로컬 token은 다음 로그인에서 다시 동기화할 수 있도록 유지합니다.
        }
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        handleForegroundNotification()

        guard let destination = destination(from: userInfo) else {
            return
        }

        onNavigate(destination)
    }

    /// 앱이 열려 있을 때는 화면을 갑자기 전환하지 않고,
    /// 목록만 새로 고쳐 배너와 알림함에서 확인하게 합니다.
    func handleForegroundNotification() {
        NotificationCenter.default.post(
            name: .maplogNotificationDidArrive,
            object: nil
        )
    }

    private func destination(
        from userInfo: [AnyHashable: Any]
    ) -> MaplogNotificationDestination? {
        let route = stringValue(for: "route", in: userInfo)

        switch route {
        case "LOG_DETAIL":
            guard let logIDString = stringValue(for: "logId", in: userInfo),
                  let logID = Int64(logIDString)
            else {
                return nil
            }

            let commentID = stringValue(for: "commentId", in: userInfo)
                .flatMap(Int64.init)
            return .logDetail(logID: logID, commentID: commentID)

        case "USER_PROFILE":
            guard let userIDString = stringValue(for: "actorUserId", in: userInfo),
                  let userID = UUID(uuidString: userIDString)
            else {
                return nil
            }
            return .userProfile(userID: userID)

        default:
            return nil
        }
    }

    private func stringValue(
        for key: String,
        in userInfo: [AnyHashable: Any]
    ) -> String? {
        if let value = userInfo[key] as? String {
            return value
        }

        if let data = userInfo["data"] as? [String: Any],
           let value = data[key] as? String {
            return value
        }

        return nil
    }
}

extension Notification.Name {
    static let maplogNotificationDidArrive = Notification.Name(
        "MaplogNotificationDidArrive"
    )
}
