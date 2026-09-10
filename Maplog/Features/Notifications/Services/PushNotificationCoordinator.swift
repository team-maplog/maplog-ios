import Foundation
import UIKit
import UserNotifications

@MainActor
protocol PushNotificationSessionManaging {
    func prepareForSignOut() async throws
    func resumeAfterSignOutAttempt() async
}

@MainActor
final class PushNotificationCoordinator: ObservableObject, PushNotificationSessionManaging {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let notificationRepository: any NotificationRepository
    private let authenticationState: any AuthenticationStateProviding
    private let tokenStore: any PushNotificationTokenStoring
    private var isSigningOut = false
    private var registrationTask: Task<Void, Error>?
    private var registrationID: UUID?

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
        // 이미 허용한 기기는 재실행·설정 복귀 때도 APNs에 등록해 새 기기 토큰을 받습니다.
        if authorizationStatus == .authorized || authorizationStatus == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// 권한은 앱 실행 직후가 아니라 사용자가 알림 목록을 열었을 때 요청합니다.
    func requestPermissionIfNeeded() async {
        await refreshAuthorizationStatus()

        guard authorizationStatus == .notDetermined else {
            return
        }

        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()

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
        guard authenticationState.isAuthenticated, !isSigningOut else { return }
        let previousTask = registrationTask
        let requestID = UUID()
        // 각 등록을 앞 요청 뒤에 연결해 빠른 토큰 갱신과 로그아웃도 같은 순서를 따릅니다.
        let task = Task { [self] in
            if let previousTask { _ = try? await previousTask.value }
            guard authenticationState.isAuthenticated, !isSigningOut else { return }
            guard let token = try tokenStore.fcmToken(), !token.isEmpty else { return }
            try await notificationRepository.registerFCMToken(FCMTokenRegistration(
                deviceID: try tokenStore.deviceID(),
                fcmToken: token
            ))
        }
        registrationTask = task
        registrationID = requestID
        defer {
            if registrationID == requestID {
                registrationTask = nil
                registrationID = nil
            }
        }
        // 실패한 토큰은 Keychain에 남겨 다음 로그인·foreground에서 재시도합니다.
        _ = try? await task.value
    }

    func prepareForSignOut() async throws {
        isSigningOut = true
        // 등록이 삭제보다 늦게 끝나면 로그아웃한 기기가 다시 등록될 수 있어 먼저 기다립니다.
        if let registrationTask {
            _ = try? await registrationTask.value
        }
        guard authenticationState.isAuthenticated else { return }
        try await notificationRepository.unregisterFCMToken(deviceID: tokenStore.deviceID())
        // FCM 토큰은 로그인 토큰이 아닙니다. 같은 기기의 다음 로그인에 재등록하도록 보관합니다.
    }

    func resumeAfterSignOutAttempt() async {
        isSigningOut = false
        // 서버 로그아웃에 실패해 세션이 남았다면 앞서 해제한 기기를 다시 연결합니다.
        await syncCachedTokenIfAuthenticated()
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        handleForegroundNotification()

        onNavigate(destination(from: userInfo) ?? .inbox)
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
        if let version = stringValue(for: "schemaVersion", in: userInfo), version != "1" {
            return nil
        }
        let route = stringValue(for: "route", in: userInfo)

        switch route {
        case "LOG_DETAIL":
            guard let logIDString = stringValue(for: "logId", in: userInfo),
                  let logID = Int64(logIDString), logID > 0
            else {
                return nil
            }

            let commentValue = stringValue(for: "commentId", in: userInfo)
            let commentID = commentValue.flatMap(Int64.init)
            if commentValue != nil, commentID == nil || (commentID ?? 0) <= 0 { return nil }
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
