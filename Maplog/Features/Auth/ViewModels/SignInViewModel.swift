//
//  SignInViewModel.swift
//  Maplog
//
//  Created by 한채림 on 7/24/26.
//

import Foundation

@MainActor
final class SignInViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""

    @Published private(set) var emailError: String?
    @Published private(set) var passwordError: String?
    @Published private(set) var formError: String?
    @Published private(set) var recoveryAction: ErrorPresentation.RecoveryAction?

    @Published private(set) var isLoading = false

    private let authRepository: any AuthRepository
    private let authSessionStore: AuthSessionStore

    init(
        authRepository: any AuthRepository,
        authSessionStore: AuthSessionStore
    ) {
        self.authRepository = authRepository
        self.authSessionStore = authSessionStore // ViewModel 안에서 AuthSessionStore()를 새로 만들지 않고 init으로 받음
    }

    func signIn() async {
        guard !isLoading else {
             return
        }

        clearErrorState()

        guard validateCredentials() else {
            return
        }

        isLoading = true

        defer {
            isLoading = false
        }

        let credentials = SignInCredentials(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password)
        do {
            let authToken = try await authRepository.signIn(credentials: credentials)

        try authSessionStore.startSession(with: authToken)
    } catch {
        apply(error)
    }
}

private func validateCredentials() -> Bool {
    emailError = AuthValidation.emailError(for: email)

    passwordError = password.isEmpty ? "비밀번호를 입력해주세요." : nil

    return emailError == nil && passwordError == nil
}

private func clearErrorState() {
    emailError = nil
    passwordError = nil
    formError = nil
    recoveryAction = nil
}

private func apply(_ error: Error ) {
    let presentation = SignInErrorPolicy.presentation(for: error)

    formError = presentation.formMessage
    emailError = presentation.emailMessage
    passwordError = presentation.passwordMessage
    recoveryAction = presentation.recoveryAction
}
}
