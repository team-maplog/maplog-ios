import SwiftUI

private enum AuthFlow: String, Identifiable {
    case email
    case signup
    case resetPassword

    var id: String { rawValue }

    var title: String {
        switch self {
        case .email: return "이메일 로그인"
        case .signup: return "회원가입"
        case .resetPassword: return "비밀번호 찾기"
        }
    }

    var subtitle: String {
        switch self {
        case .email: return "Maplog 계정으로 여행 기록을 이어가세요."
        case .signup: return "새 계정을 만들고 첫 맵로그를 시작해보세요."
        case .resetPassword: return "가입한 이메일로 재설정 링크를 보내드릴게요."
        }
    }

    var height: CGFloat {
        switch self {
        case .email: return 430
        case .signup: return 540
        case .resetPassword: return 350
        }
    }
}

private struct ResetConfirmation: Identifiable {
    let email: String
    var id: String { email }
}

final class OnboardingViewModel: ObservableObject {
    @Published var email = "chaerim@maplog.app"
    @Published var password = "maplog2026"
    @Published var signupName = "채림"
    @Published var signupEmail = "hello@maplog.app"
    @Published var signupPassword = "maplog2026"
    @Published var resetEmail = "chaerim@maplog.app"
    @Published var rememberEmail = true
    @Published var marketingOptIn = false
    @Published var toastText: String?

    var canLogin: Bool {
        !email.trimmed.isEmpty && password.count >= 6
    }

    var canSignup: Bool {
        !signupName.trimmed.isEmpty && signupEmail.contains("@") && signupPassword.count >= 6
    }

    var canResetPassword: Bool {
        resetEmail.contains("@")
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct OnboardingView: View {
    let onStart: () -> Void
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var activeFlow: AuthFlow?
    @State private var resetConfirmation: ResetConfirmation?

    var body: some View {
        NavigationStack{
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    Spacer(minLength: MaplogSpacing.xxxLarge)
                    
                    VStack(spacing: MaplogSpacing.medium) {
                        ZStack {
                            Circle()
                                .fill(Color.maplogPrimary.opacity(0.18))
                                .frame(width: 88, height: 88)
                            Circle()
                                .fill(Color.maplogPrimary)
                                .frame(width: 58, height: 58)
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 27, weight: .bold))
                                .foregroundStyle(Color.maplogTextPrimary)
                        }
                        
                        VStack(spacing: MaplogSpacing.xSmall) {
                            Text("Maplog")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .tracking(-0.8)
                                .foregroundStyle(Color.maplogTextPrimary)
                            Text("여행의 순간을 지도로 기록하세요")
                                .font(MaplogFont.body)
                                .foregroundStyle(Color.maplogTextSecondary)
                        }
                    }
                    .padding(.bottom, MaplogSpacing.xxxLarge)
                    
                    VStack(spacing: MaplogSpacing.small) {
                        loginButton(title: "이메일로 로그인", background: .maplogLime, foreground: .maplogInk, icon: "envelope.fill") {
                            activeFlow = .email
                        }
                        
                        HStack {
                            Rectangle().fill(Color.maplogBorder).frame(height: 1)
                            Text("또는")
                                .font(MaplogFont.caption)
                                .foregroundStyle(Color.maplogTextTertiary)
                            Rectangle().fill(Color.maplogBorder).frame(height: 1)
                        }
                        .padding(.vertical, MaplogSpacing.xxSmall)
                        
                        loginButton(title: "카카오로 로그인", background: Color(red: 1.0, green: 0.86, blue: 0.0), foreground: .black, icon: "message.fill") {
                            socialLogin(provider: "카카오")
                        }
                        loginButton(title: "네이버로 로그인", background: Color(red: 0.02, green: 0.78, blue: 0.33), foreground: .white, icon: "n.circle.fill") {
                            socialLogin(provider: "네이버")
                        }
                        loginButton(title: "Apple로 로그인", background: .black, foreground: .white, icon: "apple.logo") {
                            socialLogin(provider: "Apple")
                        }
                        
                        HStack(spacing: MaplogSpacing.xSmall) {
                            NavigationLink(destination: SignupView()) {
                                Text("회원가입")
                            }
                            Button("비밀번호 찾기") {
                                activeFlow = .resetPassword
                            }
                        }
                        .buttonStyle(MaplogButtonStyle(variant: .text, size: .compact))
                        .padding(.top, MaplogSpacing.xxSmall)
                    }
                    .maplogPagePadding()
                    .padding(.bottom, MaplogSpacing.xLarge)
                }
                
                if let toastText = viewModel.toastText {
                    MaplogToast(message: toastText)
                        .padding(.bottom, MaplogSpacing.xLarge)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color.maplogSurface, Color.maplogBackground],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()
        )
        .sheet(item: $activeFlow) { flow in
            AuthFlowSheet(
                flow: flow,
                viewModel: viewModel,
                onAuthenticated: onStart,
                onResetSent: {
                    resetConfirmation = ResetConfirmation(email: viewModel.resetEmail)
                    showToast("재설정 링크를 보냈어요")
                }
            )
            .presentationDetents([.height(flow.height)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $resetConfirmation) { confirmation in
            ResetLinkSentSheet(email: confirmation.email) {
                resetConfirmation = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    activeFlow = .email
                }
            }
            .presentationDetents([.height(342)])
            .presentationDragIndicator(.visible)
        }
    }

    private func loginButton(title: String, background: Color, foreground: Color, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: MaplogSpacing.small) {
                Image(systemName: icon)
                    .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                    .frame(width: MaplogSize.iconLarge)
                Text(title)
                    .frame(maxWidth: .infinity)
                Color.clear.frame(width: MaplogSize.iconLarge, height: 1)
            }
        }
        .buttonStyle(
            MaplogButtonStyle(
                variant: .brand(background: background, foreground: foreground),
                size: .large,
                fullWidth: true
            )
        )
    }

    private func socialLogin(provider: String) {
        showToast("\(provider) 계정으로 로그인했어요")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onStart()
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            viewModel.toastText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeOut(duration: 0.2)) {
                if viewModel.toastText == text {
                    viewModel.toastText = nil
                }
            }
        }
    }
}

private struct ResetLinkSentSheet: View {
    let email: String
    let onLoginTap: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.large) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(Color.maplogPrimary)
                        .frame(width: 56, height: 56)
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: MaplogSize.iconLarge, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                }

                Spacer()

                MaplogIconButton(systemName: "xmark", accessibilityLabel: "닫기") {
                    dismiss()
                }
            }

            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                Text("재설정 메일을 보냈어요")
                    .font(MaplogFont.screenTitle)
                    .foregroundStyle(Color.maplogInk)
                Text(email)
                    .font(MaplogFont.calloutStrong)
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, MaplogSpacing.small)
                    .frame(height: 34)
                    .background(Color.maplogLime.opacity(0.28))
                    .clipShape(Capsule())
                Text("메일함에서 링크를 누른 뒤 새 비밀번호를 설정하면 바로 Maplog를 이어서 사용할 수 있어요.")
                    .font(MaplogFont.body)
                    .foregroundStyle(Color.maplogMuted)
                    .lineSpacing(4)
            }

            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    onLoginTap()
                }
            } label: {
                Label("이메일 로그인으로 돌아가기", systemImage: "envelope.fill")
            }
            .buttonStyle(MaplogButtonStyle(variant: .primary, size: .large, fullWidth: true))
        }
        .padding(MaplogSpacing.xLarge)
    }
}

private struct AuthFlowSheet: View {
    let flow: AuthFlow
    @ObservedObject var viewModel: OnboardingViewModel
    let onAuthenticated: () -> Void
    let onResetSent: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var isPrimaryEnabled: Bool {
        switch flow {
        case .email: return viewModel.canLogin
        case .signup: return viewModel.canSignup
        case .resetPassword: return viewModel.canResetPassword
        }
    }

    private var primaryTitle: String {
        switch flow {
        case .email: return "로그인하고 시작하기"
        case .signup: return "계정 만들고 시작하기"
        case .resetPassword: return "재설정 링크 보내기"
        }
    }

    private var primaryIcon: String {
        switch flow {
        case .email: return "arrow.right.circle.fill"
        case .signup: return "checkmark.seal.fill"
        case .resetPassword: return "paperplane.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MaplogSpacing.large) {
                    sheetHeader

                    switch flow {
                    case .email:
                        emailForm
                    case .signup:
                        signupForm
                    case .resetPassword:
                        resetPasswordForm
                    }
                }
                .padding(.horizontal, MaplogSpacing.large)
                .padding(.top, MaplogSpacing.xLarge)
                .padding(.bottom, MaplogSpacing.xLarge)
            }

            Button {
                submit()
            } label: {
                Label(primaryTitle, systemImage: primaryIcon)
            }
            .buttonStyle(MaplogButtonStyle(variant: .primary, size: .large, fullWidth: true))
            .disabled(!isPrimaryEnabled)
            .padding(.horizontal, MaplogSpacing.large)
            .padding(.bottom, MaplogSpacing.large)
            .background(Color.maplogSurface)
        }
        .background(Color.maplogSurface)
    }

    private var sheetHeader: some View {
        HStack(alignment: .top, spacing: MaplogSpacing.small) {
            Image(systemName: headerIcon)
                .font(.system(size: MaplogSize.iconLarge, weight: .semibold))
                .foregroundStyle(Color.maplogInk)
                .frame(width: 48, height: 48)
                .background(Color.maplogPrimary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                Text(flow.title)
                    .font(MaplogFont.screenTitle)
                    .foregroundStyle(Color.maplogInk)
                Text(flow.subtitle)
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogMuted)
                    .lineSpacing(3)
            }

            Spacer()

            MaplogIconButton(systemName: "xmark", accessibilityLabel: "닫기") {
                dismiss()
            }
        }
    }

    private var emailForm: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            authTextField(title: "이메일", placeholder: "email@maplog.app", text: $viewModel.email)
            authSecureField(title: "비밀번호", placeholder: "6자 이상", text: $viewModel.password)
            Toggle(isOn: $viewModel.rememberEmail) {
                Text("이메일 기억하기")
                    .font(MaplogFont.bodyStrong)
                    .foregroundStyle(Color.maplogInk)
            }
            .tint(Color.maplogLime)
            .padding(MaplogSpacing.medium)
            .background(Color.maplogCanvas)
            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
        }
    }

    private var signupForm: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            authTextField(title: "이름", placeholder: "이름", text: $viewModel.signupName)
            authTextField(title: "이메일", placeholder: "email@maplog.app", text: $viewModel.signupEmail)
            authSecureField(title: "비밀번호", placeholder: "6자 이상", text: $viewModel.signupPassword)
            Toggle(isOn: $viewModel.marketingOptIn) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("여행 추천 알림 받기")
                        .font(MaplogFont.bodyStrong)
                        .foregroundStyle(Color.maplogInk)
                    Text("행사, 루트, 근처 장소 추천을 받아볼 수 있어요.")
                        .font(MaplogFont.caption)
                        .foregroundStyle(Color.maplogMuted)
                }
            }
            .tint(Color.maplogLime)
            .padding(MaplogSpacing.medium)
            .background(Color.maplogCanvas)
            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
        }
    }

    private var resetPasswordForm: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            authTextField(title: "가입 이메일", placeholder: "email@maplog.app", text: $viewModel.resetEmail)
            Text("이메일함에서 링크를 누르면 새 비밀번호를 설정할 수 있습니다.")
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .lineSpacing(4)
                .padding(MaplogSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.maplogCanvas)
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
        }
    }

    private var headerIcon: String {
        switch flow {
        case .email: return "envelope.fill"
        case .signup: return "person.badge.plus.fill"
        case .resetPassword: return "key.fill"
        }
    }

    private func authTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            Text(title)
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogMuted)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(MaplogFont.body)
                .foregroundStyle(Color.maplogInk)
                .padding(.horizontal, MaplogSpacing.medium)
                .frame(height: 54)
                .background(Color.maplogSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                        .stroke(Color.maplogBorder, lineWidth: 1)
                }
        }
    }

    private func authSecureField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            Text(title)
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogMuted)
            SecureField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(MaplogFont.body)
                .foregroundStyle(Color.maplogInk)
                .padding(.horizontal, MaplogSpacing.medium)
                .frame(height: 54)
                .background(Color.maplogSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                        .stroke(Color.maplogBorder, lineWidth: 1)
                }
        }
    }

    private func submit() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            switch flow {
            case .email, .signup:
                onAuthenticated()
            case .resetPassword:
                onResetSent()
            }
        }
    }
}
