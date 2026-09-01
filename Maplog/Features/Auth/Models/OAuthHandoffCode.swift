//
//  OAuthHandoffCode.swift
//  Maplog
//

import Foundation

enum OAuthCallbackError: Error, Equatable {
    case unexpectedCallback
    case missingHandoffCode
}

struct OAuthHandoffCode: Equatable {
    static let callbackHost = "maplog.millenniumrhino.com"
    static let callbackPath = "/auth/ios"

    let value: String

    init(callbackURL: URL) throws {
        // 예상한 앱 링크만 통과시킴
        guard callbackURL.scheme?.lowercased() == "https",
              callbackURL.host?.lowercased() == Self.callbackHost,
              callbackURL.path == Self.callbackPath,
              let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        else {
            throw OAuthCallbackError.unexpectedCallback
        }

        // 같은 키 반복이면 어느 값을 쓸지 모호해서 거부함
        let handoffCodes = components.queryItems?
            .filter { $0.name == "handoffCode" }
            .compactMap(\.value) ?? []

        guard handoffCodes.count == 1 else {
            throw OAuthCallbackError.missingHandoffCode
        }

        // 서버 최대 길이와 맞춰 앱에서도 먼저 검증함
        let trimmedCode = handoffCodes[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty, trimmedCode.count <= 128 else {
            throw OAuthCallbackError.missingHandoffCode
        }

        value = trimmedCode
    }
}
