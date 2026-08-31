//
//  SocialSignInViewModel.swift
//  Maplog
//

import Foundation

@MainActor
final class SocialSignInViewModel: ObservableObject {
    @Published private(set) var activeProvider: OAuthProvider?
    @Published private(set) var errorMessage: String?
    @Published private(set) var recoveryAction: ErrorPresentation.RecoveryAction?

    private let oauthRepository: any OAuthRepository
    private let webAuthenticationSession: any OAuthWebAuthenticationSession
    private let authSession: any AuthSessionManaging

    var isLoading: Bool {
        activeProvider != nil
    }

    init(
        oauthRepository: any OAuthRepository,
        webAuthenticationSession: any OAuthWebAuthenticationSession,
        authSession: any AuthSessionManaging
    ) {
        self.oauthRepository = oauthRepository
        self.webAuthenticationSession = webAuthenticationSession
        self.authSession = authSession
    }

    func signIn(provider: OAuthProvider) async {
        guard !isLoading else {
            return
        }

        errorMessage = nil
        recoveryAction = nil
        activeProvider = provider

        defer {
            activeProvider = nil
        }

        do {
            // ViewModel은 URLRequest 대신 역할 protocol만 호출함
            let redirectURL = try await oauthRepository.signInRedirectURL(for: provider)
            let callbackURL = try await webAuthenticationSession.authenticate(at: redirectURL)
            let handoffCode = try OAuthHandoffCode(callbackURL: callbackURL)
            let authToken = try await oauthRepository.exchange(handoffCode: handoffCode)
            // Keychain 저장 뒤 RootView가 로그인 상태 변화를 감지함
            try authSession.startSession(with: authToken)
        } catch {
            let presentation = SocialSignInErrorPolicy.presentation(for: error)
            errorMessage = presentation.message
            recoveryAction = presentation.recoveryAction
        }
    }
}
