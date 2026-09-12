//
//  RefreshTokenProviding.swift
//  Maplog
//
//  Created by 한채림 on 7/28/26.
//

import Foundation

@MainActor
protocol RefreshTokenProviding: AnyObject {
    func currentRefreshToken() throws -> String?
}
