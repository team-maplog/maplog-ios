//
//  DefaultLogRouteRepository.swift
//  Maplog
//
//  Created by 한채림 on 8/22/26.
// DTO를 Domain으로 바꿈

import Foundation

final class DefaultLogRouteRepository: LogRouteRepository {
    private let apiService: any LogRouteAPIService

    init(
        apiService: any LogRouteAPIService
    ) {
        self.apiService = apiService
    }

    func fetchRoute(
        logID: Int64
    ) async throws -> LogRoute {
        let routeDTO = try await apiService.fetchRoute(
            logID: logID
        )

        guard routeDTO.logID == logID else {
            throw LogRouteRepositoryError.mismatchedLogID(
                requested: logID,
                received: routeDTO.logID
            )
        }

        let points = try routeDTO.points.map(
            makeRoutePoint
        )

        guard Set(points.map(\.clipID)).count == points.count else {
            throw LogRouteRepositoryError.duplicateClipID
        }

        guard Set(points.map(\.sequence)).count == points.count else {
            throw LogRouteRepositoryError.duplicateSequence
        }

        return LogRoute(
            logID: routeDTO.logID,
            points: points.sorted {
                $0.sequence < $1.sequence
            }
        )
    }

    private func makeRoutePoint(
        from dto: RoutePointResponseDTO
    ) throws -> LogRoutePoint {
        guard dto.startTimeMillis >= 0,
              dto.endTimeMillis >= dto.startTimeMillis else {
            throw LogRouteRepositoryError.invalidTimeRange(
                clipID: dto.clipID
            )
        }

        guard dto.latitude.isFinite,
              dto.longitude.isFinite,
              (-90...90).contains(dto.latitude),
              (-180...180).contains(dto.longitude) else {
            throw LogRouteRepositoryError.invalidCoordinate(
                clipID: dto.clipID
            )
        }

        return LogRoutePoint(
            clipID: dto.clipID,
            sequence: dto.sequence,
            startTimeMillis: dto.startTimeMillis,
            endTimeMillis: dto.endTimeMillis,
            placeName: normalizedText(dto.placeName),
            address: dto.address,
            latitude: dto.latitude,
            longitude: dto.longitude,
            thumbnailURL: url(from: dto.thumbnailURL)
        )
    }

    private func url(
        from value: String?
    ) -> URL? {
        guard let value = normalizedText(value) else {
            return nil
        }

        if let absoluteURL = URL(string: value),
           absoluteURL.scheme != nil {
            return absoluteURL
        }

        return URL(
            string: value,
            relativeTo: APIConfiguration.baseURL
        )?.absoluteURL
    }

    private func normalizedText(
        _ text: String?
    ) -> String? {
        guard let text else {
            return nil
        }

        let trimmedText = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmedText.isEmpty ? nil : trimmedText
    }
}

enum LogRouteRepositoryError: Error, Equatable {
    case mismatchedLogID(
        requested: Int64,
        received: Int64
    )
    case duplicateClipID
    case duplicateSequence
    case invalidTimeRange(clipID: Int64)
    case invalidCoordinate(clipID: Int64)
}
