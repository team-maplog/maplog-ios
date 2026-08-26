import Foundation

enum SignUpField: CaseIterable, Hashable {
    case email
    case password
    case passwordConfirmation
    case nickname
    case terms
    case privacyPolicy
}

@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var email = "" {
        didSet {
            inputDidChange(.email)
        }
    }

    @Published var password = "" {
        didSet {
            inputDidChange(.password)
        }
    }

    @Published var passwordConfirmation = "" {
        didSet {
            inputDidChange(.passwordConfirmation)
        }
    }

    @Published var nickname = "" {
        didSet {
            inputDidChange(.nickname)
        }
    }

    @Published private(set) var termsAgreed = false
    @Published private(set) var privacyPolicyAgreed = false

    @Published private(set) var emailError: String?
    @Published private(set) var passwordError: String?
    @Published private(set) var passwordConfirmationError: String?
    @Published private(set) var nicknameError: String?
    @Published private(set) var termsError: String?
    @Published private(set) var privacyPolicyError: String?
    @Published private(set) var formError: String?
    @Published private(set) var recoveryAction: ErrorPresentation.RecoveryAction?
    @Published private(set) var isLoading = false

    private let authRepository: any AuthRepository
    private let authSession: any AuthSessionManaging
    private var touchedFields = Set<SignUpField>()

    init(
        authRepository: any AuthRepository,
        authSession: any AuthSessionManaging
    ) {
        self.authRepository = authRepository
        self.authSession = authSession
    }

    var canSubmit: Bool {
        !isLoading && SignUpField.allCases.allSatisfy {
            validationMessage(for: $0) == nil
        }
    }

    func didFinishEditing(_ field: SignUpField) {
        touchedFields.insert(field)
        validate(field)
    }

    func toggleTermsAgreement() {
        termsAgreed.toggle()
        inputDidChange(.terms)
    }

    func togglePrivacyPolicyAgreement() {
        privacyPolicyAgreed.toggle()
        inputDidChange(.privacyPolicy)
    }

    func signUp() async {
        guard !isLoading else {
            return
        }

        touchedFields = Set(SignUpField.allCases)
        guard validateAllFields() else {
            return
        }

        clearFormPresentation()
        isLoading = true

        defer {
            isLoading = false
        }

        let credentials = SignUpCredentials(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            passwordConfirmation: passwordConfirmation,
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            termsAgreed: termsAgreed,
            privacyPolicyAgreed: privacyPolicyAgreed
        )

        do {
            let token = try await authRepository.signUp(
                credentials: credentials
            )
            try authSession.replaceTokens(with: token)
        } catch {
            apply(SignUpErrorPolicy.presentation(for: error))
        }
    }

    private func inputDidChange(_ field: SignUpField) {
        let shouldValidateChangedField = touchedFields.contains(field)

        if shouldValidateChangedField {
            validate(field)
        }

        if field == .password,
           touchedFields.contains(.passwordConfirmation) {
            validate(.passwordConfirmation)
        }

        if shouldValidateChangedField || field == .password {
            clearFormPresentation()
        }
    }

    @discardableResult
    private func validateAllFields() -> Bool {
        SignUpField.allCases.forEach(validate)
        return canSubmit
    }

    private func validate(_ field: SignUpField) {
        let message = validationMessage(for: field)

        switch field {
        case .email:
            emailError = message
        case .password:
            passwordError = message
        case .passwordConfirmation:
            passwordConfirmationError = message
        case .nickname:
            nicknameError = message
        case .terms:
            termsError = message
        case .privacyPolicy:
            privacyPolicyError = message
        }
    }

    private func validationMessage(for field: SignUpField) -> String? {
        switch field {
        case .email:
            return AuthValidation.emailError(for: email)
        case .password:
            return AuthValidation.passwordError(for: password)
        case .passwordConfirmation:
            return AuthValidation.passwordConfirmationError(
                password: password,
                confirmation: passwordConfirmation
            )
        case .nickname:
            return AuthValidation.nicknameError(for: nickname)
        case .terms:
            return AuthValidation.termsError(termsAgreed: termsAgreed)
        case .privacyPolicy:
            return AuthValidation.privacyPolicyError(
                privacyPolicyAgreed: privacyPolicyAgreed
            )
        }
    }

    private func clearFormPresentation() {
        formError = nil
        recoveryAction = nil
    }

    private func apply(_ presentation: SignUpErrorPresentation) {
        formError = presentation.formMessage
        emailError = presentation.emailMessage
        passwordError = presentation.passwordMessage
        passwordConfirmationError = presentation.passwordConfirmationMessage
        nicknameError = presentation.nicknameMessage
        termsError = presentation.termsMessage
        privacyPolicyError = presentation.privacyPolicyMessage
        recoveryAction = presentation.recoveryAction
    }
}
