//
//  OAuthProvider.swift
//  Maplog
//

import Foundation

enum OAuthProvider: String, CaseIterable, Identifiable {
    case google
    case kakao
    case apple

    var id: String { rawValue }
}
