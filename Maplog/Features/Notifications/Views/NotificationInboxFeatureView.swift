import SwiftUI
import UIKit
import UserNotifications

struct NotificationInboxFeatureView: View {
    @Environment(\.maplogLogout) private var performLogout
    @ObservedObject private var pushNotificationCoordinator: PushNotificationCoordinator
    @StateObject private var viewModel: NotificationInboxViewModel

    private let onOpenNotification: (MaplogNotification) -> Void

    init(
        notificationRepository: any NotificationRepository,
        pushNotificationCoordinator: PushNotificationCoordinator,
        onOpenNotification: @escaping (MaplogNotification) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: NotificationInboxViewModel(
                repository: notificationRepository
            )
        )
        _pushNotificationCoordinator = ObservedObject(
            wrappedValue: pushNotificationCoordinator
        )
        self.onOpenNotification = onOpenNotification
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
                permissionStatusCard

                if let message = pushNotificationCoordinator.registrationErrorMessage {
                    NotificationPermissionCard(
                        title: "푸시 알림 연결 확인",
                        message: message,
                        actionTitle: "다시 연결",
                        action: {
                            Task {
                                await pushNotificationCoordinator.refreshAuthorizationStatus()
                                await pushNotificationCoordinator.syncCachedTokenIfAuthenticated()
                            }
                        }
                    )
                }

                content
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.top, MaplogSpacing.medium)
            .padding(.bottom, 120)
        }
        .background(Color.maplogCanvas.opacity(0.45))
        .navigationTitle("알림")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadIfNeeded()
        }
        .task {
            // 서버 응답을 기다리는 동안에도 시스템 알림 권한을 요청할 수 있어야 합니다.
            await pushNotificationCoordinator.requestPermissionIfNeeded()
        }
        .refreshable {
            await viewModel.reload()
            await pushNotificationCoordinator.refreshAuthorizationStatus()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .maplogNotificationDidArrive)
        ) { _ in
            Task {
                await viewModel.reload()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .initialLoading:
            NotificationLoadingState()

        case .content:
            LazyVStack(spacing: MaplogSpacing.small) {
                ForEach(viewModel.notifications) { notification in
                    Button {
                        onOpenNotification(notification)
                    } label: {
                        NotificationRow(notification: notification)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("관련 화면 열기")
                    .task {
                        await viewModel.loadNextPageIfNeeded(for: notification)
                    }
                }

                nextPageFooter
            }

        case .empty:
            NotificationEmptyState()

        case let .failed(presentation):
            NotificationFailureState(
                presentation: presentation,
                onRetry: {
                    Task {
                        await viewModel.reload()
                    }
                },
                onSignIn: performLogout
            )
        }
    }

    @ViewBuilder
    private var nextPageFooter: some View {
        if viewModel.isLoadingNextPage {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, MaplogSpacing.medium)
        } else if let presentation = viewModel.nextPageError {
            VStack(spacing: MaplogSpacing.small) {
                Text(presentation.message)
                    .font(.footnote)
                    .foregroundStyle(Color.maplogMuted)
                    .multilineTextAlignment(.center)

                if presentation.recoveryAction == .retry {
                    Button("다시 시도") {
                        Task {
                            await viewModel.retryNextPage()
                        }
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(minHeight: MaplogSize.minimumTapTarget)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MaplogSpacing.medium)
        }
    }

    @ViewBuilder
    private var permissionStatusCard: some View {
        switch pushNotificationCoordinator.authorizationStatus {
        case .notDetermined:
            NotificationPermissionCard(
                title: "좋아요와 댓글 소식을 받아볼까요?",
                message: "알림을 허용하면 앱을 열지 않아도 새 활동을 바로 알려드려요.",
                actionTitle: "알림 허용",
                action: requestPermission
            )

        case .denied:
            NotificationPermissionCard(
                title: "푸시 알림이 꺼져 있어요",
                message: "좋아요와 댓글은 이 목록에서 계속 확인할 수 있어요. 바로 알림을 받고 싶다면 iPhone 설정에서 켜 주세요.",
                actionTitle: "설정 열기",
                action: openSystemSettings
            )

        case .authorized, .provisional, .ephemeral:
            EmptyView()

        @unknown default:
            EmptyView()
        }
    }

    private func requestPermission() {
        Task {
            await pushNotificationCoordinator.requestPermissionIfNeeded()
        }
    }

    private func openSystemSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(settingsURL)
    }
}

private struct NotificationPermissionCard: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: MaplogSpacing.small) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.maplogPrimary)
                .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                .background(Color.maplogLime.opacity(0.24), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.maplogInk)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.maplogMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Button(actionTitle, action: action)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(minHeight: MaplogSize.minimumTapTarget)
            }
        }
        .padding(MaplogSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.maplogSurface)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 5)
    }
}

private struct NotificationRow: View {
    let notification: MaplogNotification

    var body: some View {
        HStack(alignment: .top, spacing: MaplogSpacing.small) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(
                        notification.isRead
                            ? Color.maplogLine
                            : Color.maplogLime.opacity(0.75)
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: notification.kind.symbolName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(
                        notification.isRead
                            ? Color.maplogMuted
                            : Color.maplogInk
                    )

                if !notification.isRead {
                    Circle()
                        .fill(Color.maplogPrimary)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.maplogSurface, lineWidth: 2))
                        .offset(x: 2, y: -2)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(notification.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .multilineTextAlignment(.leading)

                Text(notification.message)
                    .font(.footnote)
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(relativeDateText(for: notification.createdAt))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.maplogMuted.opacity(0.82))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.maplogMuted.opacity(0.7))
                .padding(.top, 4)
                .accessibilityHidden(true)
        }
        .padding(MaplogSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.maplogSurface)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                .stroke(
                    notification.isRead
                        ? Color.clear
                        : Color.maplogLime.opacity(0.42),
                    lineWidth: 1
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notification.kind.accessibilityTitle). \(notification.title). \(notification.message)")
    }

    private func relativeDateText(for date: Date?) -> String {
        guard let date else {
            return "새 알림"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct NotificationLoadingState: View {
    var body: some View {
        VStack(spacing: MaplogSpacing.medium) {
            ProgressView()
            Text("알림을 불러오는 중이에요")
                .font(.footnote)
                .foregroundStyle(Color.maplogMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
    }
}

private struct NotificationEmptyState: View {
    var body: some View {
        VStack(spacing: MaplogSpacing.small) {
            Image(systemName: "bell.slash")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            Text("새 알림이 없어요")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.maplogInk)
            Text("좋아요와 댓글 활동이 생기면 여기에 모아 보여드릴게요.")
                .font(.footnote)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .padding(.horizontal, MaplogSpacing.large)
        .background(Color.maplogSurface)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
    }
}

private struct NotificationFailureState: View {
    let presentation: ErrorPresentation
    let onRetry: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: MaplogSpacing.medium) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.maplogMuted)

            Text(presentation.message)
                .font(.subheadline)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)

            switch presentation.recoveryAction {
            case .retry:
                Button("다시 시도", action: onRetry)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(minHeight: MaplogSize.minimumTapTarget)
            case .signIn:
                Button("다시 로그인", action: onSignIn)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(minHeight: MaplogSize.minimumTapTarget)
            case .none:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .padding(.horizontal, MaplogSpacing.large)
        .background(Color.maplogSurface)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
    }
}
