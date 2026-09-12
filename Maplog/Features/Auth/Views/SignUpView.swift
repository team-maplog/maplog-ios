import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel: SignUpViewModel
    @FocusState private var focusedField: SignUpField?

    init(
        authRepository: any AuthRepository,
        authSession: any AuthSessionManaging
    ) {
        _viewModel = StateObject(
            wrappedValue: SignUpViewModel(
                authRepository: authRepository,
                authSession: authSession
            )
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MaplogSpacing.large) {
                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                    Text("Maplog 시작하기")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)

                    Text("기본 정보를 입력하면 바로 여행 기록을 시작할 수 있어요.")
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogMuted)
                }

                emailField
                passwordField
                passwordConfirmationField
                nicknameField
                agreementFields

                if let formError = viewModel.formError {
                    formErrorView(
                        formError,
                        recoveryAction: viewModel.recoveryAction
                    )
                }
            }
            .padding(.horizontal, MaplogSpacing.xLarge)
            .padding(.top, MaplogSpacing.xLarge)
            .padding(.bottom, MaplogSpacing.xxxLarge)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.maplogSurface)
        .navigationTitle("회원가입")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: focusedField) { previousField, currentField in
            guard previousField != currentField,
                  let previousField
            else {
                return
            }

            viewModel.didFinishEditing(previousField)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: requestSignUp) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                } else {
                    Label(
                        viewModel.recoveryAction == .retry
                            ? "다시 시도"
                            : "가입 완료",
                        systemImage: "arrow.right.circle.fill"
                    )
                }
            }
            .buttonStyle(
                MaplogButtonStyle(
                    variant: .primary,
                    size: .large,
                    fullWidth: true
                )
            )
            .disabled(!viewModel.canSubmit)
            .accessibilityHint(
                viewModel.canSubmit
                    ? "회원가입을 완료합니다."
                    : "필수 입력 항목을 모두 올바르게 작성해 주세요."
            )
            .padding(.horizontal, MaplogSpacing.xLarge)
            .padding(.vertical, MaplogSpacing.medium)
            .background(Color.maplogSurface)
        }
    }

    private var emailField: some View {
        SignUpInputSection(
            title: "이메일 주소",
            message: viewModel.emailFeedback
        ) {
            TextField("example@maplog.app", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .password
                }
                .signUpInputStyle(error: viewModel.emailError)
        }
    }

    private var passwordField: some View {
        SignUpInputSection(
            title: "비밀번호",
            message: viewModel.passwordFeedback,
            helper: "8~72자, 영문 소문자·숫자·특수문자를 포함해 주세요."
        ) {
            SecureField("비밀번호를 입력해주세요", text: $viewModel.password)
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .passwordConfirmation
                }
                .signUpInputStyle(error: viewModel.passwordError)
        }
    }

    private var passwordConfirmationField: some View {
        SignUpInputSection(
            title: "비밀번호 확인",
            message: viewModel.passwordConfirmationFeedback
        ) {
            SecureField(
                "비밀번호를 한 번 더 입력해주세요",
                text: $viewModel.passwordConfirmation
            )
            .textContentType(.newPassword)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .passwordConfirmation)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .nickname
            }
            .signUpInputStyle(error: viewModel.passwordConfirmationError)
        }
    }

    private var nicknameField: some View {
        SignUpInputSection(
            title: "닉네임",
            message: viewModel.nicknameFeedback,
            helper: "2~20자, 한글·영문·숫자와 단일 공백만 사용할 수 있어요."
        ) {
            TextField("사용할 닉네임", text: $viewModel.nickname)
                .textContentType(.nickname)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .nickname)
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                }
                .signUpInputStyle(error: viewModel.nicknameError)
        }
    }

    private var agreementFields: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            HStack(spacing: MaplogSpacing.medium) {
                Link("이용약관 보기", destination: MaplogLegalLinks.terms)
                Link("개인정보 처리방침 보기", destination: MaplogLegalLinks.privacy)
            }
            .font(MaplogFont.caption)
            .foregroundStyle(Color.maplogInk)
            .padding(.vertical, 8)
            SignUpAgreementRow(
                title: "이용약관 동의 (필수)",
                isAgreed: viewModel.termsAgreed,
                message: viewModel.termsError,
                action: {
                    focusedField = nil
                    viewModel.toggleTermsAgreement()
                }
            )

            SignUpAgreementRow(
                title: "개인정보 처리방침 동의 (필수)",
                isAgreed: viewModel.privacyPolicyAgreed,
                message: viewModel.privacyPolicyError,
                action: {
                    focusedField = nil
                    viewModel.togglePrivacyPolicyAgreement()
                }
            )
        }
    }

    private func formErrorView(
        _ message: String,
        recoveryAction: ErrorPresentation.RecoveryAction?
    ) -> some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            Text(message)
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogDanger)

            if recoveryAction == .retry {
                Button("다시 시도", action: requestSignUp)
                    .font(MaplogFont.caption.weight(.semibold))
                    .foregroundStyle(Color.maplogInk)
                    .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func requestSignUp() {
        focusedField = nil

        Task {
            await viewModel.signUp()
        }
    }
}

private struct SignUpInputSection<Content: View>: View {
    let title: String
    let message: String?
    let helper: String?
    @ViewBuilder let content: Content

    init(
        title: String,
        message: String?,
        helper: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.message = message
        self.helper = helper
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            Text(title)
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogMuted)

            content

            if let message {
                Text(message)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogDanger)
                    .accessibilityLabel("\(title): \(message)")
            } else if let helper {
                Text(helper)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogMuted)
            }
        }
    }
}

private struct SignUpAgreementRow: View {
    let title: String
    let isAgreed: Bool
    let message: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
            Button(action: action) {
                HStack(spacing: MaplogSpacing.small) {
                    Image(systemName: isAgreed ? "checkmark" : "")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: 24, height: 24)
                        .background(
                            isAgreed ? Color.maplogLime : Color.maplogSurface,
                            in: Circle()
                        )
                        .overlay {
                            Circle()
                                .stroke(
                                    isAgreed
                                        ? Color.maplogLime
                                        : Color.maplogOlive.opacity(0.38),
                                    lineWidth: 1
                                )
                        }

                    Text(title)
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogInk)

                    Spacer(minLength: 0)
                }
                .frame(minHeight: MaplogSize.minimumTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isAgreed ? "동의함" : "동의하지 않음")

            if let message {
                Text(message)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogDanger)
            }
        }
    }
}

private extension View {
    func signUpInputStyle(error: String?) -> some View {
        font(MaplogFont.body)
            .foregroundStyle(Color.maplogInk)
            .padding(.horizontal, MaplogSpacing.medium)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.maplogSurfaceRaised)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: MaplogRadius.medium,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: MaplogRadius.medium,
                    style: .continuous
                )
                .stroke(
                    error == nil ? Color.maplogBorder : Color.maplogDanger,
                    lineWidth: 1
                )
            }
    }
}
