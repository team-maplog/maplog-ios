//
//  OAuthWebAuthenticationSession.swift
//  Maplog
//

import AuthenticationServices
import UIKit

enum OAuthWebAuthenticationSessionError: Error, Equatable {
    case cancelled
    case couldNotStart
    case presentationContextUnavailable
}

@MainActor
protocol OAuthWebAuthenticationSession {
    func authenticate(at url: URL) async throws -> URL
}

@MainActor
final class SystemOAuthWebAuthenticationSession: NSObject,
    OAuthWebAuthenticationSession,
    ASWebAuthenticationPresentationContextProviding {

    // 완료 전까지 세션이 사라지지 않게 보관함
    private var authenticationSession: ASWebAuthenticationSession?
    // 인증 창을 띄운 실제 UIWindow 보관함. 세션 도중 다른 빈 창을 반환하지 않게 함
    private var activePresentationAnchor: ASPresentationAnchor?

    func authenticate(at url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            // 활성 창 없으면 임시 UIWindow 만들지 않음. 팝업이 바로 해제되는 문제 막음
            guard let activePresentationAnchor = currentPresentationAnchor() else {
                continuation.resume(
                    throwing: OAuthWebAuthenticationSessionError.presentationContextUnavailable
                )
                return
            }

            // host와 path까지 맞을 때만 인증 완료 처리함
            let callback = ASWebAuthenticationSession.Callback.https(
                host: OAuthHandoffCode.callbackHost,
                path: OAuthHandoffCode.callbackPath
            )
            let session = ASWebAuthenticationSession(
                url: url,
                callback: callback
            ) { [weak self] callbackURL, error in
                self?.clearActiveSession()

                if let error {
                    let authenticationError = error as? ASWebAuthenticationSessionError
                    if authenticationError?.code == .canceledLogin {
                        continuation.resume(throwing: OAuthWebAuthenticationSessionError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: OAuthWebAuthenticationSessionError.couldNotStart)
                    return
                }

                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            self.activePresentationAnchor = activePresentationAnchor
            authenticationSession = session

            guard session.canStart, session.start() else {
                clearActiveSession()
                continuation.resume(throwing: OAuthWebAuthenticationSessionError.couldNotStart)
                return
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // authenticate 시작 전에 검증·보관한 실제 창만 반환함
        guard let activePresentationAnchor else {
            assertionFailure("OAuth presentation anchor must exist before starting a session.")
            return ASPresentationAnchor()
        }
        return activePresentationAnchor
    }

    private func currentPresentationAnchor() -> ASPresentationAnchor? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: \.isKeyWindow)
    }

    private func clearActiveSession() {
        authenticationSession = nil
        activePresentationAnchor = nil
    }
}
