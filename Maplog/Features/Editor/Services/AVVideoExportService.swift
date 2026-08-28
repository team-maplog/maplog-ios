//
//  AVVideoExportService.swift
//  Maplog
//

import AVFoundation
import CoreGraphics
import Foundation

/// 앱 내부 초안을 하나의 결과 영상으로 렌더링합니다.
///
/// 일반 모드는 타임라인에 순서대로 넣고, 분할 모드는 서로 다른 composition track에
/// 같은 시간(0초)부터 넣습니다. 따라서 2·3분할은 여러 카메라를 동시에 녹화한 것이
/// 아니라 사용자가 순서대로 고른 클립을 한 캔버스에 함께 배치한 결과입니다.
actor AVVideoExportService: VideoExportService {
    private let fileManager: FileManager
    private let textOverlayRenderer: any VideoTextOverlayRendering

    init(
        fileManager: FileManager = .default,
        textOverlayRenderer: any VideoTextOverlayRendering
    ) {
        self.fileManager = fileManager
        self.textOverlayRenderer = textOverlayRenderer
    }

    func export(
        request: VideoExportRequest
    ) async throws -> VideoExportResult {
        guard !request.clips.isEmpty else {
            throw VideoExportServiceError.noSourceVideos
        }

        let plan = try await makeExportPlan(for: request)
        let outputURL = try makeOutputURL()

        guard let exportSession = AVAssetExportSession(
            asset: plan.composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoExportServiceError.unableToCreateExportSession
        }

        exportSession.videoComposition = plan.videoComposition

        do {
            try await exportSession.export(to: outputURL, as: .mov)

            return VideoExportResult(
                fileURL: outputURL,
                duration: plan.duration.seconds
            )
        } catch {
            try? fileManager.removeItem(at: outputURL)
            throw error
        }
    }

    private func makeExportPlan(
        for request: VideoExportRequest
    ) async throws -> VideoExportPlan {
        switch request.compositionConfiguration.layout {
        case .single:
            return try await makeSequentialPlan(for: request)
        case .splitTwo, .splitThree:
            return try await makeSplitPlan(for: request)
        }
    }

    private func makeSequentialPlan(
        for request: VideoExportRequest
    ) async throws -> VideoExportPlan {
        let composition = AVMutableComposition()

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoExportServiceError.unableToCreateCompositionTrack
        }

        let compositionAudioTrack = try makeAudioTrack(
            in: composition,
            isMuted: request.isMuted
        )

        var insertionTime = CMTime.zero
        var instructions: [AVMutableVideoCompositionInstruction] = []
        let renderSize = request.compositionConfiguration.renderSize
        let targetFrame = request.compositionConfiguration.sceneFrame

        for clip in request.clips where clip.mediaType == .video {
            let source = try await makeSourceVideo(for: clip)
            let sourceRange = CMTimeRange(
                start: .zero,
                duration: source.duration
            )

            try compositionVideoTrack.insertTimeRange(
                sourceRange,
                of: source.videoTrack,
                at: insertionTime
            )

            try await insertAudioIfPossible(
                from: source.asset,
                sourceRange: sourceRange,
                into: compositionAudioTrack,
                at: insertionTime
            )

            let layerInstruction = try await makeLayerInstruction(
                for: compositionVideoTrack,
                sourceVideoTrack: source.videoTrack,
                destinationFrame: targetFrame,
                at: insertionTime,
                contentMode: .fit
            )

            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(
                start: insertionTime,
                duration: source.duration
            )
            instruction.layerInstructions = [layerInstruction]
            instructions.append(instruction)

            insertionTime = CMTimeAdd(insertionTime, source.duration)
        }

        guard insertionTime > .zero else {
            throw VideoExportServiceError.sourceVideoUnavailable
        }

        let timeline = ClipEditorTimeline(clips: request.clips)
        let videoComposition = makeVideoComposition(
            renderSize: renderSize,
            instructions: instructions,
            textOverlays: request.textOverlays,
            timeline: timeline
        )

        return VideoExportPlan(
            composition: composition,
            videoComposition: videoComposition,
            duration: insertionTime
        )
    }

    private func makeSplitPlan(
        for request: VideoExportRequest
    ) async throws -> VideoExportPlan {
        let configuration = request.compositionConfiguration
        let visibleClips = Array(
            request.clips.prefix(configuration.requiredClipCount)
        )

        guard visibleClips.count == configuration.requiredClipCount else {
            throw VideoExportServiceError.noSourceVideos
        }

        var sources: [SourceVideo] = []
        for clip in visibleClips {
            sources.append(try await makeSourceVideo(for: clip))
        }

        guard let sharedDuration = sources.map(\.duration).min(),
              sharedDuration > .zero
        else {
            throw VideoExportServiceError.sourceVideoUnavailable
        }

        let composition = AVMutableComposition()
        let compositionAudioTrack = try makeAudioTrack(
            in: composition,
            isMuted: request.isMuted
        )
        let renderSize = configuration.renderSize
        let sceneFrame = configuration.sceneFrame
        let frames = configuration.layout.normalizedFrames(
            for: configuration.sceneOrientation
        ).map { normalizedFrame in
            CGRect(
                x: sceneFrame.minX + normalizedFrame.minX * sceneFrame.width,
                y: sceneFrame.minY + normalizedFrame.minY * sceneFrame.height,
                width: normalizedFrame.width * sceneFrame.width,
                height: normalizedFrame.height * sceneFrame.height
            )
        }

        var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []
        let sharedRange = CMTimeRange(start: .zero, duration: sharedDuration)

        for (index, source) in sources.enumerated() {
            guard let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw VideoExportServiceError.unableToCreateCompositionTrack
            }

            try compositionVideoTrack.insertTimeRange(
                sharedRange,
                of: source.videoTrack,
                at: .zero
            )

            if index == 0 {
                try await insertAudioIfPossible(
                    from: source.asset,
                    sourceRange: sharedRange,
                    into: compositionAudioTrack,
                    at: .zero
                )
            }

            let layerInstruction = try await makeLayerInstruction(
                for: compositionVideoTrack,
                sourceVideoTrack: source.videoTrack,
                destinationFrame: frames[index],
                at: .zero,
                contentMode: .fill
            )
            layerInstructions.append(layerInstruction)
        }

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = sharedRange
        instruction.layerInstructions = layerInstructions

        let timeline = ClipEditorTimeline(
            clips: visibleClips,
            compositionConfiguration: configuration
        )
        let videoComposition = makeVideoComposition(
            renderSize: renderSize,
            instructions: [instruction],
            textOverlays: request.textOverlays,
            timeline: timeline
        )

        return VideoExportPlan(
            composition: composition,
            videoComposition: videoComposition,
            duration: sharedDuration
        )
    }

    private func makeAudioTrack(
        in composition: AVMutableComposition,
        isMuted: Bool
    ) throws -> AVMutableCompositionTrack? {
        guard !isMuted else {
            return nil
        }

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoExportServiceError.unableToCreateCompositionTrack
        }

        return audioTrack
    }

    private func makeSourceVideo(
        for clip: CaptureDraftClip
    ) async throws -> SourceVideo {
        let asset = AVURLAsset(url: clip.fileURL)

        guard let videoTrack = try await asset.loadTracks(
            withMediaType: .video
        ).first else {
            throw VideoExportServiceError.sourceVideoUnavailable
        }

        let duration = try await asset.load(.duration)

        guard duration.seconds.isFinite, duration.seconds > 0 else {
            throw VideoExportServiceError.sourceVideoUnavailable
        }

        return SourceVideo(
            asset: asset,
            videoTrack: videoTrack,
            duration: duration
        )
    }

    private func insertAudioIfPossible(
        from asset: AVURLAsset,
        sourceRange: CMTimeRange,
        into compositionAudioTrack: AVMutableCompositionTrack?,
        at insertionTime: CMTime
    ) async throws {
        guard
            let compositionAudioTrack,
            let sourceAudioTrack = try await asset.loadTracks(
                withMediaType: .audio
            ).first
        else {
            return
        }

        try compositionAudioTrack.insertTimeRange(
            sourceRange,
            of: sourceAudioTrack,
            at: insertionTime
        )
    }

    private func makeLayerInstruction(
        for compositionTrack: AVCompositionTrack,
        sourceVideoTrack: AVAssetTrack,
        destinationFrame: CGRect,
        at time: CMTime,
        contentMode: VideoSlotContentMode
    ) async throws -> AVMutableVideoCompositionLayerInstruction {
        let placement = try await VideoCompositionPlacement.make(
            for: sourceVideoTrack,
            in: destinationFrame,
            contentMode: contentMode
        )
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(
            assetTrack: compositionTrack
        )

        if let sourceCropRect = placement.sourceCropRect {
            layerInstruction.setCropRectangle(sourceCropRect, at: time)
        }
        layerInstruction.setTransform(placement.transform, at: time)

        return layerInstruction
    }

    private func makeVideoComposition(
        renderSize: CGSize,
        instructions: [AVMutableVideoCompositionInstruction],
        textOverlays: [ClipTextOverlay],
        timeline: ClipEditorTimeline
    ) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = instructions
        videoComposition.instructions.forEach { instruction in
            (instruction as? AVMutableVideoCompositionInstruction)?
                .backgroundColor = CGColor(gray: 0, alpha: 1)
        }
        videoComposition.animationTool = textOverlayRenderer.makeAnimationTool(
            overlays: textOverlays,
            timeline: timeline,
            renderSize: renderSize
        )

        return videoComposition
    }

    private func makeOutputURL() throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let exportDirectory = applicationSupportURL.appendingPathComponent(
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

private struct VideoExportPlan {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition
    let duration: CMTime
}

private struct SourceVideo {
    let asset: AVURLAsset
    let videoTrack: AVAssetTrack
    let duration: CMTime
}
