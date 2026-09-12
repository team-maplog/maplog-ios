import Foundation

final class DefaultLogDetailRepository: LogDetailRepository {
    private let apiService: any LogDetailAPIService

    init(
        apiService: any LogDetailAPIService
    ) {
        self.apiService = apiService
    }

    func fetchDetail(
        logID: Int64
    ) async throws -> LogDetail {
        let detailDTO = try await apiService.fetchLogDetail(logID: logID)
        return try LogResponseMapper.makeLogDetail(from: detailDTO)
    }

    func updateLog(
        logID: Int64,
        draft: LogUpdateDraft
    ) async throws -> LogUpdateResult {
        let responseDTO = try await apiService.updateLog(
            logID: logID,
            request: UpdateLogRequestDTO(
                caption: draft.caption,
                tags: draft.tags?.map(\.rawValue),
                address: draft.address,
                clips: draft.clips?.map { clip in
                    UpdateLogClipLocationDTO(
                        logClipID: clip.logClipID,
                        location: LogCreateLocationDTO(
                            name: clip.location.name, address: clip.location.address,
                            latitude: clip.location.latitude, longitude: clip.location.longitude
                        )
                    )
                }
            )
        )

        return LogUpdateResult(
            caption: responseDTO.caption,
            tags: responseDTO.tags.map { LogTag.makeTags(from: $0) }
                ?? draft.tags
                ?? [],
            address: responseDTO.address,
            // PATCH 응답에는 클립이 없으므로 성공한 장소 변경만 상세 상태에 반영합니다.
            updatedLocations: draft.clips ?? []
        )
    }

    func deleteLog(
        logID: Int64
    ) async throws {
        try await apiService.deleteLog(logID: logID)
    }
}
