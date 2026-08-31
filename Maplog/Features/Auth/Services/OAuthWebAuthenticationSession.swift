//
//  OAuthWebAuthenticationSession.swift
//  Maplog
//

import AuthenticationServices
import UIKit

enum OAuthWebAuthenticationSessionError: Error, Equatable {
    case cancelled
    case couldNotStart
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

    func authenticate(at url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            // host와 path까지 맞을 때만 인증 완료 처리함
            let callback = ASWebAuthenticationSession.Callback.https(
                host: OAuthHandoffCode.callbackHost,
                path: OAuthHandoffCode.callbackPath
            )
            let session = ASWebAuthenticationSession(
                url: url,
                callback: callback
            ) { [weak self] callbackURL, error in
                self?.authenticationSession = nil

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
            authenticationSession = session

            guard session.start() else {
                authenticationSession = nil
                continuation.resume(throwing: OAuthWebAuthenticationSessionError.couldNotStart)
                return
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
