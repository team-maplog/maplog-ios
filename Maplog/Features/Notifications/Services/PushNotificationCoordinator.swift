import Foundation
import OSLog
import UIKit
import UserNotifications

@MainActor
protocol PushNotificationSessionManaging {
    func prepareForSignOut() async throws
    func resumeAfterSignOutAttempt() async
}

@MainActor
final class PushNotificationCoordinator: ObservableObject, PushNotificationSessionManaging {
    @Published private(set) var registrationErrorMessage: String?
    private let logger = Logger(subsystem: "com.maplog.app", category: "PushRegistration")
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let notificationRepository: any NotificationRepository
    private let authenticationState: any AuthenticationStateProviding
    private let tokenStore: any PushNotificationTokenStoring
    private var isSigningOut = false
    private var isRequestingPermission = false
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
        logger.info("Notification authorization status: \(self.authorizationStatus.rawValue)")
        // 이미 허용한 기기는 재실행·설정 복귀 때도 APNs에 등록해 새 기기 토큰을 받습니다.
        if authorizationStatus == .authorized || authorizationStatus == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// 권한은 앱 실행 직후가 아니라 사용자가 알림 목록을 열었을 때 요청합니다.
    func requestPermissionIfNeeded() async {
        // 화면 진입과 허용 버튼이 겹쳐도 시스템 요청은 한 번만 진행합니다.
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        await refreshAuthorizationStatus()

        guard authorizationStatus == .notDetermined else {
            return
        }

        do {
            logger.info("Notification permission request started")
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            logger.info("Notification permission request completed, granted: \(granted)")
            await refreshAuthorizationStatus()

        } catch {
            logger.error("Notification permission request failed, error code: \((error as NSError).code)")
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
        // 등록 실패를 숨기면 앱 내 알림은 보이지만 푸시는 오지 않는 상태를 알 수 없습니다.
        do {
            try await task.value
            if registrationID == requestID {
                registrationErrorMessage = nil
            }
            logger.info("Push token synchronization finished")
        } catch {
            if registrationID == requestID {
                registrationErrorMessage = "이 기기에 알림을 연결하지 못했어요. 다시 시도해 주세요."
            }
            // 토큰·서버 본문·사용자 정보는 진단 로그에 남기지 않습니다.
            logger.error("Push token synchronization failed")
        }
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
