//
//  DefaultPublishingRepository.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// 업로드 → fileId 받기 → 로그 생성 순서를 관리

import Foundation

final class DefaultLogPublishingRepository: LogPublishingRepository {
    private let apiService: any LogPublishingAPIService

    init(
        apiService: any LogPublishingAPIService
    ) {
        self.apiService = apiService
    }

    func publish(
        draft: LogPublishDraft
    ) async throws -> LogPublishResult {
        let uploadDTO = try await apiService.uploadLogVideo(
            fileURL: draft.videoFileURL
        )

        let requestDTO = makeLogCreateRequest(
            draft: draft,
            videoFileID: uploadDTO.fileId
        )

        let createDTO = try await apiService.createLog(
            request: requestDTO
        )

        return LogPublishResult(
            logID: createDTO.logId
        )
    }

    private func makeLogCreateRequest(
        draft: LogPublishDraft,
        videoFileID: Int64
    ) -> LogCreateRequestDTO {
        LogCreateRequestDTO(
            caption: draft.caption,
            tags: draft.tags,
            address: draft.representativeAddress,
            videoFileId: videoFileID,
            thumbnailTimeMillis: draft.thumbnailTimeMillis,
            clips: draft.clips.map(makeLogCreateClip)
        )
    }

    private func makeLogCreateClip(
        from draft: LogPublishClipDraft
    ) -> LogCreateClipDTO {
        LogCreateClipDTO(
            location: LogCreateLocationDTO(
                name: draft.location.name,
                address: draft.location.address,
                latitude: draft.location.latitude,
                longitude: draft.location.longitude
            ),
            startTimeMillis: draft.startTimeMillis,
            endTimeMillis: draft.endTimeMillis
        )
    }
}
