//
//  AccessTokenRefreshing.swift
//  Maplog
//
//  Created by 한채림 on 7/28/26.
//

import Foundation

@MainActor
protocol AccessTokenRefreshing: AnyObject {
    func refreshAccessToken() async throws
}
