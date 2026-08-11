//
//  DefaultLogLocationRepository.swift
//  Maplog
//
//  Created by 한채림 on 8/12/26.
// Service가 받아 온 서버 DTO를 앱의 Domain Model로 바꿈

import Foundation

final class DefaultLogLocationRepository: LogLocationRepository {
    private let apiService: any LogLocationAPIService

    init(
        apiService: any LogLocationAPIService
    ) {
        self.apiService = apiService
    }

    func resolveLocation(
        latitude: Double,
        longitude: Double
    ) async throws -> ResolvedLogLocation {
        let locationDTO = try await apiService.resolveLocation(
            latitude: latitude,
            longitude: longitude
        )

        return ResolvedLogLocation(
            latitude: locationDTO.latitude,
            longitude: locationDTO.longitude,
            name: normalizedName(locationDTO.name),
            address: locationDTO.address
        )
    }

    private func normalizedName(
        _ name: String?
    ) -> String? {
        guard let name else {
            return nil
        }

        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmedName.isEmpty ? nil : trimmedName
    }
}
