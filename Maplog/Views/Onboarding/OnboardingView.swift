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
    @Published var email = ""
    @Published var password = ""
    @Published var signupName = "채림"
    @Published var signupEmail = ""
    @Published var signupPassword = ""
    @Published var resetEmail = ""
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
    let authRepository: any AuthRepository
    private let authSession: any AuthSessionManaging

    @StateObject private var viewModel = OnboardingViewModel()
    @StateObject private var socialSignInViewModel: SocialSignInViewModel
    @State private var activeFlow: AuthFlow?
    @State private var resetConfirmation: ResetConfirmation?

    init(
        authRepository: any AuthRepository,
        oauthRepository: any OAuthRepository,
        webAuthenticationSession: any OAuthWebAuthenticationSession,
        authSession: any AuthSessionManaging,
        sessionLifecycle: any AuthSessionLifecycleManaging
    ) {
        self.authRepository = authRepository
        self.authSession = authSession
        _socialSignInViewModel = StateObject(
            wrappedValue: SocialSignInViewModel(
                oauthRepository: oauthRepository,
                webAuthenticationSession: webAuthenticationSession,
                sessionLifecycle: sessionLifecycle
            )
        )
    }

    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize: CGFloat = 30

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        welcomeHeading
                            .padding(.horizontal, 24)

                        // 장식은 화면 높이에 맞춰 줄이고, 접근성 큰 글씨·작은 기기에서는 스크롤을 허용합니다.
                        Image("LoginJourneyArtwork")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: max(150, min(310, geometry.size.height - 490)))
                            .accessibilityHidden(true)

                        loginActions
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .center)
                }
                .background(Color.white)
                .overlay(alignment: .bottom) {
                    if let toastText = viewModel.toastText {
                        MaplogToast(message: toastText)
                            .padding(.bottom, MaplogSpacing.xLarge)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .background(Color.white.ignoresSafeArea())
        }
        .sheet(item: $activeFlow) { flow in
            AuthFlowSheet(
                flow: flow,
                viewModel: viewModel,
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
            }
            .presentationDetents([.height(342)])
            .presentationDragIndicator(.visible)
        }
    }

    private var welcomeHeading: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                MaplogPinGlyphIcon(size: 22)
                    .foregroundStyle(Color.maplogLime)
                Text("Maplog")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .tracking(-0.5)
            }
            .foregroundStyle(Color.maplogInk)
            .accessibilityElement(children: .combine)
            .padding(.bottom, 28)

            Text("여행의 순간을\n나만의 지도로.")
                .font(.system(size: headlineSize, weight: .bold))
                .tracking(-0.8)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Color.maplogInk)

            Text("사진과 영상으로 남기는 나의 여행 기록")
                .font(.subheadline)
                .foregroundStyle(Color.maplogMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
    }

    private var loginActions: some View {
        VStack(spacing: 10) {
            NavigationLink {
                SignInView(authRepository: authRepository, authSession: authSession)
            } label: {
                OnboardingLoginButtonLabel(title: "이메일로 로그인", icon: "envelope")
            }
            .buttonStyle(MaplogButtonStyle(
                variant: .brand(background: .maplogLime, foreground: .maplogInk),
                size: .regular,
                fullWidth: true
            ))
            .disabled(socialSignInViewModel.isLoading)
            .accessibilityIdentifier("welcome.email")

            HStack(spacing: 14) {
                Rectangle().fill(Color.maplogLine).frame(height: 1)
                Text("또는").font(.caption).foregroundStyle(Color.maplogMuted)
                Rectangle().fill(Color.maplogLine).frame(height: 1)
            }
            .padding(.vertical, 3)

            socialLoginButton(provider: .google, background: .white, foreground: .maplogInk, icon: "")
                .overlay {
                    RoundedRectangle(cornerRadius: MaplogRadius.medium)
                        .stroke(Color.maplogLine, lineWidth: 1)
                        .allowsHitTesting(false)
                }
            socialLoginButton(
                provider: .kakao,
                background: Color(red: 254 / 255, green: 229 / 255, blue: 0),
                foreground: .black,
                icon: "bubble.left.fill"
            )
            socialLoginButton(provider: .apple, background: .black, foreground: .white, icon: "apple.logo")

            if let message = socialSignInViewModel.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.maplogDanger)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 14) {
                NavigationLink {
                    SignUpView(authRepository: authRepository, authSession: authSession)
                } label: {
                    Text("회원가입").frame(minHeight: 44)
                }
                Text("|").foregroundStyle(Color.maplogLine).accessibilityHidden(true)
                Button { activeFlow = .resetPassword } label: {
                    Text("비밀번호 찾기").frame(minHeight: 44)
                }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color.maplogMuted)
            .buttonStyle(.plain)
            .disabled(socialSignInViewModel.isLoading)
            .padding(.top, 12)
        }
    }

    private func socialLoginButton(
        provider: OAuthProvider,
        background: Color,
        foreground: Color,
        icon: String
    ) -> some View {
        Button {
            Task {
                await socialSignInViewModel.signIn(provider: provider)
            }
        } label: {
            OnboardingLoginButtonLabel(
                title: socialSignInViewModel.activeProvider == provider
                    ? "로그인 중..."
                    : "\(provider.displayName)로 계속하기",
                icon: icon,
                imageAsset: provider == .google ? "GoogleSignInGlyph" : nil
            )
        }
        .buttonStyle(
            MaplogButtonStyle(
                variant: .brand(background: background, foreground: foreground),
                size: .regular,
                fullWidth: true
            )
        )
        .disabled(socialSignInViewModel.isLoading)
        .accessibilityLabel("\(provider.displayName)로 로그인")
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

private extension OAuthProvider {
    var displayName: String {
        switch self {
        case .google: return "Google"
        case .kakao: return "카카오"
        case .apple: return "Apple"
        }
    }
}

private struct OnboardingLoginButtonLabel: View {
    let title: String
    let icon: String
    var imageAsset: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let imageAsset {
                    Image(imageAsset)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 21, weight: .medium))
                }
            }
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)

            Text(title)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
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
                .foregroundStyle(Color.maplogOnPrimary)
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
                break
            case .resetPassword:
                onResetSent()
            }
        }
    }
}
