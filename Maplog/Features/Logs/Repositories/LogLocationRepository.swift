//
//  LogLocationRepository.swift
//  Maplog
//
//  Created by 한채림 on 8/12/26.
//
//위도 경도를 주면,서버 형식이 아닌 ResolvedLogLocation을 돌려줄 수 있음
import Foundation

protocol LogLocationRepository {
    func searchLocations(query: String, near location: LogLocationDraft) async throws -> [LogLocationDraft]

    func resolveLocation(
        latitude: Double,
        longitude: Double
    ) async throws -> ResolvedLogLocation
}
