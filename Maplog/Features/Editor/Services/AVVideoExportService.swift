//
//  AVVideoExportService.swift
//  Maplog
//
//  Created by 한채림 on 8/3/26.
// 여러 원본 영상 → 순서대로 하나의 타임라인에 배치 → 새 .mov 파일로 저장

//ClipEditorViewModel
//  └─ 선택 순서대로 fileURL 목록 생성
//       └─ AVVideoExportService
//            ├─ 빈 타임라인 생성
//            ├─ A 영상 삽입
//            ├─ B 영상 삽입
//            ├─ C 영상 삽입
//            └─ 하나의 새 .mov로 export
//                 └─ VideoExportResult 반환

import AVFoundation
import Foundation

actor AVVideoExportService: VideoExportService {
    private let fileManager: FileManager // 파일 관리자 주입, 영상 결과 파일 저장, 실패한 결과 파일 삭제
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
//    → video track, audio track을 각각 삽입
//    → video track의 preferredTransform 적용
//    → 결과 영상의 세로 renderSize 지정
    func export(
        request: VideoExportRequest
    ) async throws -> VideoExportResult {
        guard !request.clips.isEmpty else {
            throw VideoExportServiceError.noSourceVideos
        }

        let composition = AVMutableComposition()

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoExportServiceError.unableToCreateCompositionTrack
        }

        var insertionTime = CMTime.zero
        var instructions: [AVMutableVideoCompositionInstruction] = []
        var renderSize: CGSize?

        for clip in request.clips {
            let asset = AVURLAsset(url: clip.fileURL)

            guard let videoTrack = try await asset
                .loadTracks(withMediaType: .video)
                .first
            else {
                throw VideoExportServiceError.sourceVideoUnavailable
            }

            let duration = try await asset.load(.duration)

            guard duration.seconds.isFinite,
                  duration.seconds > 0
            else {
                throw VideoExportServiceError.sourceVideoUnavailable
            }

            let sourceTimeRange = CMTimeRange(
                start: .zero,
                duration: duration
            )

            try compositionVideoTrack.insertTimeRange(
                sourceTimeRange,
                of: videoTrack,
                at: insertionTime
            )

            let audioTracks = try await asset.loadTracks(
                withMediaType: .audio
            )

            if let audioTrack = audioTracks.first {
                try compositionAudioTrack.insertTimeRange(
                    sourceTimeRange,
                    of: audioTrack,
                    at: insertionTime
                )
            }

            let preferredTransform = try await videoTrack.load(
                .preferredTransform
            )

            let naturalSize = try await videoTrack.load(.naturalSize)

            let transformedSize = naturalSize.applying(
                preferredTransform
            )

            let orientedSize = CGSize(
                width: abs(transformedSize.width),
                height: abs(transformedSize.height)
            )

            guard orientedSize.width > 0,
                  orientedSize.height > 0
            else {
                throw VideoExportServiceError.sourceVideoUnavailable
            }

            if renderSize == nil {
                renderSize = orientedSize
            }

            let instruction = AVMutableVideoCompositionInstruction()

            instruction.timeRange = CMTimeRange(
                start: insertionTime,
                duration: duration
            )

            let layerInstruction =
                AVMutableVideoCompositionLayerInstruction(
                    assetTrack: compositionVideoTrack
                )

            layerInstruction.setTransform(
                preferredTransform,
                at: insertionTime
            )

            instruction.layerInstructions = [layerInstruction]

            instructions.append(instruction)

            insertionTime = CMTimeAdd(
                insertionTime,
                duration
            )
        }

        guard let renderSize else {
            throw VideoExportServiceError.sourceVideoUnavailable
        }

        let videoComposition = AVMutableVideoComposition()

        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(
            value: 1,
            timescale: 30
        )
        videoComposition.instructions = instructions

        let outputURL = try makeOutputURL()

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoExportServiceError.unableToCreateExportSession
        }

        exportSession.videoComposition = videoComposition

        do {
            try await exportSession.export(
                to: outputURL,
                as: .mov
            )

            return VideoExportResult(
                fileURL: outputURL,
                duration: insertionTime.seconds
            )
        } catch {
            try? fileManager.removeItem(at: outputURL)
            throw error
        }
    }
    
//    composition: A → B → C 순서로 이어진 영상 설계
//    outputURL: 결과 파일을 저장할 주소
//    .mov: 결과 포맷
//    await: 영상 길이에 따라 시간이 걸리므로 완료를 기다림
    
    private func makeOutputURL() throws -> URL { // 앱 전용 저장소인 Application Support 폴더를 가져옴 사진 앱 갤러리가 아니라 Maplog 앱 내부 저장소
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
            )
        
        let exportDirectory = applicationSupportURL
                    .appendingPathComponent(
                        "EditedVideos",
                        isDirectory: true
                    )

                try fileManager.createDirectory(
                    at: exportDirectory,
                    withIntermediateDirectories: true
                )

                return exportDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
    }
}

//Application Support
// └─ EditedVideos
//     └─ UUID.mov
