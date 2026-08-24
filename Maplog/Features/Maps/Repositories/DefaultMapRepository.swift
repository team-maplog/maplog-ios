//
//  DefaultMapRepository.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
//

import Foundation

final class DefaultMapRepository: MapRepository {
    private let apiService: any MapAPIService

    init(
        apiService: any MapAPIService
    ) {
        self.apiService = apiService
    }

    func fetchViewportContent(
        in viewport: MapViewport
    ) async throws -> MapViewportContent {
        let responseDTO = try await apiService.fetchViewportContent(
            in: viewport
        )

        let logMarkers = (responseDTO.markers ?? []).compactMap(
            makeLogMarker
        )

        let tourismResponseDTO = responseDTO.tourisms

        let tourismMarkers = (
            tourismResponseDTO?.markers ?? []
        ).compactMap(
            makeTourismMarker
        )

        return MapViewportContent(
            logMarkers: logMarkers,
            tourismMarkers: tourismMarkers,
            isLogMarkerTruncated: responseDTO.truncated ?? false,
            tourismStatus: TourismMapStatus(
                isAvailable: tourismResponseDTO?.available ?? false,
                isStale: tourismResponseDTO?.stale ?? false,
                isTruncated: tourismResponseDTO?.truncated ?? false
            )
        )
    }

    private func makeLogMarker(
        from dto: LogMapMarkerResponseDTO
    ) -> MapLogMarker? {
        guard let logID = dto.logID,
              logID > 0,
              let clipID = dto.clipID,
              clipID > 0,
              let sequence = dto.sequence,
              sequence > 0,
              let startTimeMillis = dto.startTimeMillis,
              startTimeMillis >= 0,
              let endTimeMillis = dto.endTimeMillis,
              endTimeMillis >= startTimeMillis,
              let latitude = dto.latitude,
              let longitude = dto.longitude,
              isValidCoordinate(
                  latitude: latitude,
                  longitude: longitude
              )
        else {
            return nil
        }

        return MapLogMarker(
            logID: logID,
            clipID: clipID,
            sequence: sequence,
            startTimeMillis: startTimeMillis,
            endTimeMillis: endTimeMillis,
            caption: normalizedText(dto.caption),
            placeName: normalizedText(dto.placeName),
            address: normalizedText(dto.address),
            thumbnailURL: makeURL(from: dto.thumbnailURL),
            coordinate: MapCoordinate(
                latitude: latitude,
                longitude: longitude
            )
        )
    }

    private func makeTourismMarker(
        from dto: TourismMapMarkerResponseDTO
    ) -> TourismMapMarker? {
        guard let tourismID = dto.tourismID,
              tourismID > 0,
              let latitude = dto.latitude,
              let longitude = dto.longitude,
              isValidCoordinate(
                  latitude: latitude,
                  longitude: longitude
              )
        else {
            return nil
        }

        return TourismMapMarker(
            tourismID: tourismID,
            name: normalizedText(dto.name),
            thumbnailURL: makeURL(from: dto.thumbnailURL),
            startDateText: normalizedText(dto.startDate),
            endDateText: normalizedText(dto.endDate),
            coordinate: MapCoordinate(
                latitude: latitude,
                longitude: longitude
            )
        )
    }

    private func isValidCoordinate(
        latitude: Double,
        longitude: Double
    ) -> Bool {
        guard latitude.isFinite,
              longitude.isFinite
        else {
            return false
        }

        return (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
    }

    private func normalizedText(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func makeURL(
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
}
