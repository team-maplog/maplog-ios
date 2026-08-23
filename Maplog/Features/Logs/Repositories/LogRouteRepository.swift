//
//  LogRouteRepository.swift
//  Maplog
//
//  Created by 한채림 on 8/22/26.
//

import Foundation

protocol LogRouteRepository {
    func fetchRoute(
        logID: Int64
    ) async throws -> LogRoute
}
