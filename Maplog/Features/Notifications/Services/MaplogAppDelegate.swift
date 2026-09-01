import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

/// Firebase·APNs 콜백을 앱의 알림 기능으로 전달하는 UIKit 진입점입니다.
/// 네트워크·화면 이동 규칙은 이 객체가 아니라 Coordinator가 담당합니다.
final class MaplogAppDelegate: NSObject,
    UIApplicationDelegate,
    UNUserNotificationCenterDelegate,
    MessagingDelegate {
    private var fcmTokenHandler: (@MainActor (String) -> Void)?
    private var remoteNotificationHandler: (@MainActor ([AnyHashable: Any]) -> Void)?
    private var foregroundNotificationHandler: (@MainActor () -> Void)?
    private var pendingFCMToken: String?
    private var pendingRemoteNotification: [AnyHashable: Any]?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard Bundle.main.path(
            forResource: "GoogleService-Info",
            ofType: "plist"
        ) != nil else {
            // 로컬 Firebase 설정 파일이 없는 협업 환경에서도 앱이 시작될 수 있게 둡니다.
            return true
        }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func installHandlers(
        onFCMToken: @escaping @MainActor (String) -> Void,
        onRemoteNotification: @escaping @MainActor ([AnyHashable: Any]) -> Void,
        onForegroundNotification: @escaping @MainActor () -> Void
    ) {
        fcmTokenHandler = onFCMToken
        remoteNotificationHandler = onRemoteNotification
        foregroundNotificationHandler = onForegroundNotification

        if let pendingFCMToken {
            deliverFCMToken(pendingFCMToken)
        } else if FirebaseApp.app() != nil {
            Messaging.messaging().token { [weak self] token, _ in
                guard let token else {
                    return
                }
                self?.deliverFCMToken(token)
            }
        }

        if let pendingRemoteNotification {
            self.pendingRemoteNotification = nil
            deliverRemoteNotification(pendingRemoteNotification)
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken, !fcmToken.isEmpty else {
            return
        }

        deliverFCMToken(fcmToken)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        deliverForegroundNotification()
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        deliverRemoteNotification(response.notification.request.content.userInfo)
    }

    private func deliverFCMToken(_ token: String) {
        pendingFCMToken = token

        guard let fcmTokenHandler else {
            return
        }

        Task { @MainActor in
            fcmTokenHandler(token)
        }
    }

    private func deliverRemoteNotification(
        _ userInfo: [AnyHashable: Any]
    ) {
        guard let remoteNotificationHandler else {
            pendingRemoteNotification = userInfo
            return
        }

        Task { @MainActor in
            remoteNotificationHandler(userInfo)
        }
    }

    private func deliverForegroundNotification() {
        guard let foregroundNotificationHandler else {
            return
        }

        Task { @MainActor in
            foregroundNotificationHandler()
        }
    }
}
