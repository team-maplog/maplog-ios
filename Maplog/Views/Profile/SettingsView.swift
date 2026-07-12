import SwiftUI

private struct SettingsRoute: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let detailTitle: String
    let detailBody: String
}

struct SettingsView: View {
    @Environment(\.maplogLogout) private var maplogLogout
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var showUpdateToast = false
    @State private var toastText = ""
    @State private var showLogoutDialog = false
    @State private var showWithdrawDialog = false

    private let accountRoutes = [
        SettingsRoute(id: "password", title: "비밀번호 변경", icon: "lock.fill", detailTitle: "비밀번호 변경", detailBody: "현재 비밀번호를 확인하고 새 비밀번호로 계정을 안전하게 보호하세요."),
        SettingsRoute(id: "security", title: "계정 보안", icon: "checkmark.shield.fill", detailTitle: "계정 보안", detailBody: "로그인 기기, 2단계 인증, 최근 접근 기록을 한곳에서 확인합니다.")
    ]

    private let serviceRoutes = [
        SettingsRoute(id: "terms", title: "이용약관", icon: "doc.text.fill", detailTitle: "이용약관", detailBody: "Maplog 이용을 위해 필요한 기본 약관과 서비스 운영 기준을 확인합니다."),
        SettingsRoute(id: "privacy", title: "개인정보 처리방침", icon: "hand.raised.fill", detailTitle: "개인정보 처리방침", detailBody: "위치, 촬영 기록, 저장 루트 등 개인정보가 어떻게 보호되는지 안내합니다."),
        SettingsRoute(id: "license", title: "오픈소스 라이선스", icon: "curlybraces", detailTitle: "오픈소스 라이선스", detailBody: "Maplog 앱에 포함된 오픈소스 라이선스 정보를 확인합니다.")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                    settingsSection("계정 설정") {
                        NavigationLink {
                            ProfileEditView {
                                showToastTemporarily("프로필을 저장했어요")
                            }
                        } label: {
                            SettingsNavigationRow(title: "프로필 편집")
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()

                        ForEach(accountRoutes) { route in
                            NavigationLink {
                                SettingsDetailView(route: route)
                            } label: {
                                SettingsNavigationRow(title: route.title)
                            }
                            .buttonStyle(.plain)

                            if route.id != accountRoutes.last?.id {
                                SettingsDivider()
                            }
                        }
                    }

                    settingsSection("알림 설정") {
                        SettingsToggleRow(title: "푸시 알림", isOn: pushNotificationsBinding)
                        SettingsDivider()
                        SettingsToggleRow(title: "서비스 공지 알림", isOn: serviceAnnouncementsBinding)
                    }

                    settingsSection("서비스 정보") {
                        ForEach(serviceRoutes) { route in
                            NavigationLink {
                                SettingsDetailView(route: route)
                            } label: {
                                SettingsNavigationRow(title: route.title)
                            }
                            .buttonStyle(.plain)

                            if route.id != serviceRoutes.last?.id {
                                SettingsDivider()
                            }
                        }
                    }

                    settingsSection("앱 정보") {
                        SettingsValueRow(title: "현재 버전", value: "v1.0.4")
                        SettingsDivider()
                        Button {
                            showToastTemporarily("현재 최신 버전입니다.")
                        } label: {
                            SettingsNavigationRow(title: "업데이트 확인")
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection("기타") {
                        Button {
                            showLogoutDialog = true
                        } label: {
                            SettingsActionRow(title: "로그아웃")
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()

                        Button(role: .destructive) {
                            showWithdrawDialog = true
                        } label: {
                            SettingsActionRow(title: "회원 탈퇴", tint: .red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .maplogPagePadding()
                .padding(.top, MaplogSpacing.pageTop)
                .padding(.bottom, MaplogSpacing.xxxLarge)
            }

            if showUpdateToast {
                MaplogToast(message: toastText)
                    .padding(.bottom, MaplogSpacing.large)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("로그아웃할까요?", isPresented: $showLogoutDialog, titleVisibility: .visible) {
            Button("로그아웃") {
                maplogLogout()
            }
            Button("취소", role: .cancel) {
                showLogoutDialog = false
            }
        } message: {
            Text("현재 계정으로 다시 로그인할 수 있습니다.")
        }
        .confirmationDialog("회원 탈퇴", isPresented: $showWithdrawDialog, titleVisibility: .visible) {
            Button("회원 탈퇴", role: .destructive) {
                maplogLogout()
            }
            Button("취소", role: .cancel) {
                showWithdrawDialog = false
            }
        } message: {
            Text("탈퇴 시 저장된 기록은 복구할 수 없습니다.")
        }
        .maplogScreenSurface()
        .maplogNavigationAppearance()
        .maplogTabBarHidden()
    }

    private var pushNotificationsBinding: Binding<Bool> {
        Binding(
            get: { sessionStore.notificationSettings.pushNotificationsEnabled },
            set: { isEnabled in
                sessionStore.setPushNotificationsEnabled(isEnabled)
                showToastTemporarily(isEnabled ? "푸시 알림을 켰어요" : "푸시 알림을 껐어요")
            }
        )
    }

    private var serviceAnnouncementsBinding: Binding<Bool> {
        Binding(
            get: { sessionStore.notificationSettings.serviceAnnouncementsEnabled },
            set: { isEnabled in
                sessionStore.setServiceAnnouncementsEnabled(isEnabled)
                showToastTemporarily(isEnabled ? "서비스 공지 알림을 켰어요" : "서비스 공지 알림을 껐어요")
            }
        )
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            Text(title)
                .font(MaplogFont.calloutStrong)
                .foregroundStyle(Color.maplogTextSecondary)
                .padding(.horizontal, MaplogSpacing.xxSmall)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.maplogSurface)
            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous)
                    .stroke(Color.maplogBorder.opacity(0.9), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.035), radius: 6, x: 0, y: 2)
        }
    }

    private func showToastTemporarily(_ text: String) {
        toastText = text
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            showUpdateToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                showUpdateToast = false
            }
        }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.maplogLine.opacity(0.8))
            .frame(height: 1)
    }
}

private struct SettingsNavigationRow: View {
    let title: String

    var body: some View {
        HStack(spacing: MaplogSpacing.small) {
            Text(title)
                .font(MaplogFont.body)
                .foregroundStyle(Color.maplogInk)

            Spacer()

            Image(systemName: "chevron.right")
                .font(MaplogFont.calloutStrong)
                .foregroundStyle(Color.maplogMuted.opacity(0.86))
        }
        .padding(.horizontal, MaplogSpacing.medium)
        .frame(height: 58)
        .contentShape(Rectangle())
    }
}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(MaplogFont.body)
                .foregroundStyle(Color.maplogInk)

            Spacer()

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(Color.maplogLime)
        }
        .padding(.horizontal, MaplogSpacing.medium)
        .frame(height: 58)
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.maplogInk)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.maplogMuted)
        }
        .padding(.horizontal, MaplogSpacing.medium)
        .frame(height: 58)
    }
}

private struct SettingsActionRow: View {
    let title: String
    var tint: Color = .maplogInk

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)
            Spacer()
        }
        .padding(.horizontal, MaplogSpacing.medium)
        .frame(height: 58)
        .contentShape(Rectangle())
    }
}

private struct SettingsDetailInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.maplogMuted)

            Spacer(minLength: 18)

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.maplogInk)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, MaplogSpacing.medium)
        .frame(minHeight: 54)
    }
}

private enum SettingsActionSheet: Identifiable {
    case password
    case security

    var id: String {
        switch self {
        case .password:
            return "password"
        case .security:
            return "security"
        }
    }
}

private struct SettingsDetailView: View {
    let route: SettingsRoute
    @Environment(\.dismiss) private var dismiss
    @State private var activeSheet: SettingsActionSheet?
    @State private var toastText: String?
    @State private var twoFactorEnabled = false
    @State private var loginAlertsEnabled = true

    private var detailRows: [(String, String)] {
        switch route.id {
        case "password":
            return [("마지막 변경", "3개월 전"), ("권장 주기", "90일마다 변경"), ("상태", "보안 양호")]
        case "security":
            return [("로그인 기기", "2대"), ("2단계 인증", twoFactorEnabled ? "켜짐" : "꺼짐"), ("최근 접근", "오늘 18:42")]
        case "terms":
            return [("최종 개정일", "2026. 06. 01"), ("적용 대상", "Maplog 전체 서비스")]
        case "privacy":
            return [("최종 개정일", "2026. 06. 01"), ("수집 항목", "위치 · 기록 · 저장 루트")]
        case "license":
            return [("라이선스", "SwiftUI · Apple Frameworks"), ("고지 방식", "앱 내 공개")]
        default:
            return [("상태", "확인 가능")]
        }
    }

    private var actionTitle: String {
        switch route.id {
        case "password": return "비밀번호 변경하기"
        case "security": return "보안 설정 확인"
        default: return "확인"
        }
    }

    private var actionIcon: String {
        switch route.id {
        case "password": return "key.fill"
        case "security": return "shield.lefthalf.filled"
        default: return "checkmark"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(Color.maplogCanvas)
                            .frame(width: 112, height: 112)
                        Image(systemName: route.icon)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(Color.maplogOlive)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(route.detailTitle)
                            .font(MaplogFont.largeTitle)
                            .foregroundStyle(Color.maplogInk)
                        Text(route.detailBody)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.maplogMuted)
                            .lineSpacing(5)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(detailRows.enumerated()), id: \.offset) { index, row in
                            SettingsDetailInfoRow(title: row.0, value: row.1)
                            if index != detailRows.count - 1 {
                                SettingsDivider()
                            }
                        }
                    }
                    .background(Color(.systemGray6).opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                            .stroke(Color.maplogLine.opacity(0.9), lineWidth: 1)
                    }

                    PrimaryActionButton(actionTitle, systemImage: actionIcon) {
                        handlePrimaryAction()
                    }
                }
                .padding(MaplogSpacing.large)
                .padding(.bottom, 40)
            }

            if let toastText {
                Text(toastText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(Color.maplogSurface)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.maplogSurface)
        .maplogTabBarHidden()
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .password:
                PasswordChangeSheet { message in
                    activeSheet = nil
                    showToast(message)
                }
                .presentationDetents([.height(432)])
                .presentationDragIndicator(.visible)
            case .security:
                SecuritySettingsSheet(
                    initialTwoFactorEnabled: twoFactorEnabled,
                    initialLoginAlertsEnabled: loginAlertsEnabled
                ) { twoFactor, loginAlerts, message in
                    twoFactorEnabled = twoFactor
                    loginAlertsEnabled = loginAlerts
                    activeSheet = nil
                    showToast(message)
                }
                .presentationDetents([.height(486)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func handlePrimaryAction() {
        switch route.id {
        case "password":
            activeSheet = .password
        case "security":
            activeSheet = .security
        default:
            dismiss()
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            toastText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeOut(duration: 0.2)) {
                if toastText == text {
                    toastText = nil
                }
            }
        }
    }
}

private struct PasswordChangeSheet: View {
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = "maplog2026"
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    private var canSubmit: Bool {
        !currentPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
    }

    private var helperText: String {
        if newPassword.isEmpty && confirmPassword.isEmpty {
            return "6자 이상 새 비밀번호를 입력하세요."
        }
        if newPassword.count < 6 {
            return "새 비밀번호는 6자 이상이어야 합니다."
        }
        if newPassword != confirmPassword {
            return "새 비밀번호 확인이 일치하지 않습니다."
        }
        return "비밀번호 변경 준비가 완료됐어요."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sheetHeader(title: "비밀번호 변경", subtitle: "목데이터 계정의 비밀번호 변경 흐름을 확인합니다.")

            VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                secureField(title: "현재 비밀번호", text: $currentPassword)
                secureField(title: "새 비밀번호", text: $newPassword)
                secureField(title: "새 비밀번호 확인", text: $confirmPassword)

                Label(helperText, systemImage: canSubmit ? "checkmark.circle.fill" : "info.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(canSubmit ? Color.maplogOlive : Color.maplogMuted)
                    .padding(MaplogSpacing.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.maplogCanvas.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    onComplete("비밀번호를 변경했어요")
                }
            } label: {
                Label("변경 완료", systemImage: "checkmark.seal.fill")
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(canSubmit ? Color.maplogLime : Color.maplogLine)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
        .padding(MaplogSpacing.xLarge)
    }

    private func sheetHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(MaplogFont.screenTitle)
                    .foregroundStyle(Color.maplogInk)
                Text(subtitle)
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogMuted)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 36, height: 36)
                    .background(Color.maplogCanvas)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func secureField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            SecureField(title, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.maplogInk)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color.maplogCanvas)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct SecuritySettingsSheet: View {
    let onComplete: (Bool, Bool, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var twoFactorEnabled: Bool
    @State private var loginAlertsEnabled: Bool

    init(
        initialTwoFactorEnabled: Bool,
        initialLoginAlertsEnabled: Bool,
        onComplete: @escaping (Bool, Bool, String) -> Void
    ) {
        self.onComplete = onComplete
        _twoFactorEnabled = State(initialValue: initialTwoFactorEnabled)
        _loginAlertsEnabled = State(initialValue: initialLoginAlertsEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("계정 보안")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text("로그인 기기와 보안 알림 상태를 점검하세요.")
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogMuted)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: 36, height: 36)
                        .background(Color.maplogCanvas)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                SettingsToggleRow(title: "2단계 인증", isOn: $twoFactorEnabled)
                SettingsDivider()
                SettingsToggleRow(title: "새 기기 로그인 알림", isOn: $loginAlertsEnabled)
            }
            .background(Color.maplogCanvas.opacity(0.74))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("로그인 기기")
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogInk)

                SecurityDeviceRow(name: "iPhone 17 Pro", detail: "현재 기기 · 서울 · 방금 전", isCurrent: true)
                SecurityDeviceRow(name: "MacBook Pro", detail: "서울 · 오늘 18:42", isCurrent: false)
            }

            HStack(spacing: 10) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        onComplete(twoFactorEnabled, loginAlertsEnabled, "다른 기기 세션을 정리했어요")
                    }
                } label: {
                    Text("기기 정리")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: 116, height: 52)
                        .background(Color.maplogCanvas)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        onComplete(twoFactorEnabled, loginAlertsEnabled, twoFactorEnabled ? "보안 설정을 강화했어요" : "보안 설정을 저장했어요")
                    }
                } label: {
                    Label("저장", systemImage: "checkmark")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MaplogSpacing.xLarge)
    }
}

private struct SecurityDeviceRow: View {
    let name: String
    let detail: String
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: MaplogSpacing.small) {
            Image(systemName: isCurrent ? "iphone.gen3" : "laptopcomputer")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.maplogOlive)
                .frame(width: 44, height: 44)
                .background(Color.maplogCanvas)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                Text(detail)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.maplogMuted)
            }

            Spacer()

            if isCurrent {
                Text("현재")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, MaplogSpacing.xSmall)
                    .frame(height: 24)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
        }
        .padding(MaplogSpacing.small)
        .background(Color.maplogSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.maplogLine.opacity(0.9), lineWidth: 1)
        }
    }
}
