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
    private let sessionLifecycle: any AuthSessionLifecycleManaging

    var isLoading: Bool {
        activeProvider != nil
    }

    init(
        oauthRepository: any OAuthRepository,
        webAuthenticationSession: any OAuthWebAuthenticationSession,
        sessionLifecycle: any AuthSessionLifecycleManaging
    ) {
        self.oauthRepository = oauthRepository
        self.webAuthenticationSession = webAuthenticationSession
        self.sessionLifecycle = sessionLifecycle
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
            // handoff token은 /users/me 검증을 통과한 경우에만 홈 전환 상태가 됨
            try await sessionLifecycle.establishSession(with: authToken)
        } catch {
            let presentation = SocialSignInErrorPolicy.presentation(for: error)
            errorMessage = presentation.message
            recoveryAction = presentation.recoveryAction
        }
    }
}
