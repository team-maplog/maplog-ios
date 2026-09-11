//
//  AVVideoPlaybackService.swift
//  Maplog
//
//  Created by 한채림 on 8/2/26.
//

//1번 클립 탭
//→ ViewModel이 1번 클립의 fileURL 확인
//→ playbackService.loadVideo(at: fileURL)
//→ 기존 재생 영상 교체
//→ VideoPlayer가 같은 player를 보고 있으므로 화면도 교체

//AVVideoExportService
//→ 이어 붙인 결과를 .mov 파일로 저장
//
//AVVideoPlaybackService
//→ 이어 붙인 결과를 즉시 화면에서 재생

import AVFoundation
import Foundation

@MainActor
final class AVVideoPlaybackService: VideoPlaybackService {
    private let queuePlayer = AVQueuePlayer()
    private var playerLooper: AVPlayerLooper?
    private var periodicTimeObserver: Any? // AVPlayer가 주기적으로 알려주는 재생 시간을 해제하기 위해 보관하는 토큰

    private struct PendingSeek {
        let time: CMTime
        let completion: @Sendable (Bool) -> Void
    }

    private var pendingSeek: PendingSeek?
    private var currentItemObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private weak var observedItem: AVPlayerItem?

    var player: AVPlayer {
        queuePlayer
    }

    var isMuted: Bool {
        queuePlayer.isMuted
    }

    func toggleMute() {
        queuePlayer.isMuted.toggle()
    }

    func loadVideo(at url: URL) { // 영상 교체·반복 재생 준비
        stop() // 새 영상을 넣기 전, Service 상태를 항상 깨끗하게 초기화

        let templateItem = AVPlayerItem(url: url) // 다운로드한 Caches/LogPlayback/log-2.video 같은 실제 로컬 영상 파일을 재생 가능한 AVPlayerItem으로 감쌈

        playerLooper = AVPlayerLooper(
            player: queuePlayer,
            templateItem: templateItem
        )
    }

    func loadVideoSequence(
        from urls: [URL]
    ) async throws {
        guard !urls.isEmpty else {
            throw VideoPlaybackServiceError.noSourceVideos
        }

        stop()

        let templateItem = try await makeSequenceItem(
            from: urls
        )

        playerLooper = AVPlayerLooper(
            player: queuePlayer,
            templateItem: templateItem
        )
    }

    func loadVideoComposition(
        from clips: [CaptureDraftClip],
        configuration: VideoCompositionConfiguration
    ) async throws {
        let videos = clips.filter { $0.mediaType == .video }
        let templateItem: AVPlayerItem
        if configuration.layout == .single {
            templateItem = try await makeSequenceItem(
                from: videos.map(\.fileURL),
                configuration: configuration,
                crops: videos.map { configuration.clipCrops[$0.id] ?? VideoClipCrop() }
            )
        } else {
            templateItem = try await makeSplitCompositionItem(from: clips, configuration: configuration)
        }
        try Task.checkCancellation()
        // 준비가 끝날 때 교체해 구도 변경 중 기존 화면이 검게 비지 않게 한다.
        stop()
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: templateItem)
    }

    // 재생 위치 이동 기능
//    seek(to: 0)
//    → 전체 영상 맨 처음 A 시작
//
//    seek(to: 2)
//    → B가 시작하는 시점
//
//    seek(to: 7)
//    → C가 시작하는 시점
    func seek(
        to seconds: TimeInterval
    ) {
        seek(to: seconds) { _ in }
    }

    func seek(
        to seconds: TimeInterval,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        let safeSeconds = max(seconds, 0)

        let time = CMTime(
            seconds: safeSeconds,
            preferredTimescale: 600
        )

        cancelPendingSeek()

        pendingSeek = PendingSeek(
            time: time,
            completion: completion
        )

        observeCurrentItem()
        performPendingSeekIfPossible()
    }

    private func observeCurrentItem() {
        guard currentItemObservation == nil else {
            return
        }

        currentItemObservation = queuePlayer.observe(
            \.currentItem,
            options: [.initial, .new]
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.performPendingSeekIfPossible()
            }
        }
    }

    private func performPendingSeekIfPossible() {
        guard let pendingSeek,
              let item = queuePlayer.currentItem
        else {
            return
        }

        switch item.status {
        case .readyToPlay:
            let request = pendingSeek

            cancelPendingSeek()

            queuePlayer.seek(
                to: request.time,
                toleranceBefore: .zero,
                toleranceAfter: .zero,
                completionHandler: request.completion
            )

        case .failed:
            pendingSeek.completion(false)
            cancelPendingSeek()

        case .unknown:
            observeStatus(of: item)

        @unknown default:
            pendingSeek.completion(false)
            cancelPendingSeek()
        }
    }

    private func observeStatus(
        of item: AVPlayerItem
    ) {
        guard observedItem !== item else {
            return
        }

        itemStatusObservation?.invalidate()
        observedItem = item

        itemStatusObservation = item.observe(
            \.status,
            options: [.initial, .new]
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.performPendingSeekIfPossible()
            }
        }
    }

    private func cancelPendingSeek() {
        pendingSeek = nil

        currentItemObservation?.invalidate()
        currentItemObservation = nil

        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        observedItem = nil
    }

    func play() {
        queuePlayer.play()
    }

    func pause() {
        queuePlayer.pause()
    }

    func stop() {
        cancelPendingSeek()
        removeProgressObserver()
        queuePlayer.pause()

        playerLooper?.disableLooping()
        playerLooper = nil

        queuePlayer.removeAllItems()
    }

    func observeProgress(_ handler: @escaping (Double) -> Void) {
        removeProgressObserver()

        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)

        periodicTimeObserver = queuePlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            guard let self else {
                 return
            }

            let duration = queuePlayer.currentItem?.duration.seconds ?? 0

            guard duration.isFinite,
                  duration > 0,
                  time.seconds.isFinite
            else {
                 return
            }

            let progress = min(
                max(time.seconds / duration, 0),
                1
                )
            handler(progress)
        }
    }

    // 영상들을 메모리 안에서 이어 붙임, 파일로 내보내지 않고, AVPlayerItem으로 만들어 즉시 재생
    private func makeSequenceItem(
        from urls: [URL],
        configuration: VideoCompositionConfiguration? = nil,
        crops: [VideoClipCrop] = []
    ) async throws -> AVPlayerItem {
        let composition = AVMutableComposition()

        guard
            let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ),
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            throw VideoPlaybackServiceError
                .unableToCreateCompositionTrack
        }

        var insertionTime = CMTime.zero
        var instructions: [AVMutableVideoCompositionInstruction] = []
        var renderSize: CGSize?

        for (index, url) in urls.enumerated() {
            let asset = AVURLAsset(url: url)

            guard let sourceVideoTrack = try await asset
                .loadTracks(withMediaType: .video)
                .first
            else {
                throw VideoPlaybackServiceError
                    .sourceVideoUnavailable
            }

            let duration = try await asset.load(.duration)

            guard duration.seconds.isFinite,
                  duration.seconds > 0
            else {
                throw VideoPlaybackServiceError
                    .sourceVideoUnavailable
            }

            let timeRange = CMTimeRange(
                start: .zero,
                duration: duration
            )

            try compositionVideoTrack.insertTimeRange(
                timeRange,
                of: sourceVideoTrack,
                at: insertionTime
            )

            let sourceAudioTrack = try await asset
                .loadTracks(withMediaType: .audio)
                .first

            if let sourceAudioTrack {
                try compositionAudioTrack.insertTimeRange(
                    timeRange,
                    of: sourceAudioTrack,
                    at: insertionTime
                )
            }

            let preferredTransform = try await sourceVideoTrack
                .load(.preferredTransform)

            let naturalSize = try await sourceVideoTrack
                .load(.naturalSize)

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
                throw VideoPlaybackServiceError
                    .sourceVideoUnavailable
            }

            if renderSize == nil {
                renderSize = orientedSize
            }

            // 특정 시간 구간에서는 이렇게 그려라는 한 장의 지시서
            let instruction = AVMutableVideoCompositionInstruction()

//            A 길이: 2초
//            B 길이: 3초
//
//            A instruction: 0초 ~ 2초
//            B instruction: 2초 ~ 5초

            instruction.timeRange = CMTimeRange(
                start: insertionTime,
                duration: duration
            )

            // 시간 구간에 영상을 어떤 방식으로 화면에 놓을지 설명
            let layerInstruction =
                AVMutableVideoCompositionLayerInstruction(
                    assetTrack: compositionVideoTrack
                ) // compositionVideoTrack은 A, B, C가 시간 순서대로 들어간 하나의 비디오 레일

            if let configuration {
                renderSize = configuration.renderSize
                let placement = try await VideoCompositionPlacement.make(
                    for: sourceVideoTrack,
                    in: configuration.sceneFrame,
                    contentMode: .fit,
                    crop: crops.indices.contains(index) ? crops[index] : VideoClipCrop()
                )
                layerInstruction.setTransform(placement.transform, at: insertionTime)
            } else {
                layerInstruction.setTransform(preferredTransform, at: insertionTime)
            }

//            layerInstructions: 이 시간 구간에 적용할 실제 그림 규칙
//            instructions: A용, B용, C용 지시서를 계속 모아 두는 배열
            instruction.layerInstructions = [layerInstruction]
            instructions.append(instruction)


//            처음: insertionTime = 0초
//
//            A 2초 추가
//            → insertionTime = 2초
//
//            B 3초 추가
//            → insertionTime = 5초
//
//            C 1초 추가
//            → insertionTime = 6초
            insertionTime = CMTimeAdd(
                insertionTime,
                duration
            )
        }

        guard let renderSize else {
            throw VideoPlaybackServiceError
                .sourceVideoUnavailable
        }

        // 지금까지 만든 여러 instruction을 하나로 모으는 최종 영상 렌더링 설정
        let videoComposition = AVMutableVideoComposition()


        // 현재는 첫 영상의 방향을 적용한 크기를 기준으로 사용
//        1 / 30초
//        = 초당 30장
//        = 30fps
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(
            value: 1,
            timescale: 30
        )
        videoComposition.instructions = instructions

//        composition은 A→B→C가 이어진 미디어 타임라인이고, 그것을 실제 재생 가능한 AVPlayerItem으로 감쌈
        let item = AVPlayerItem(asset: composition)
        item.videoComposition = videoComposition // 그냥 이어진 원본을 재생하지 말고, 위에서 만든 회전·크기·시간대 규칙을 적용해서 재생

        return item
    }

    /// 분할 모드의 편집 화면도 export와 같은 시간축(0초부터 동시에)을 사용한다.
    /// 따라서 사용자는 "영상 만들기"를 누르기 전부터 실제 2·3분할 결과를 확인한다.
    private func makeSplitCompositionItem(
        from clips: [CaptureDraftClip],
        configuration: VideoCompositionConfiguration
    ) async throws -> AVPlayerItem {
        let visibleClips = Array(
            clips
                .filter { $0.mediaType == .video }
                .prefix(configuration.requiredClipCount)
        )

        guard visibleClips.count == configuration.requiredClipCount else {
            throw VideoPlaybackServiceError.noSourceVideos
        }

        let sources = try await visibleClips.asyncMap {
            clip in
            try await makeSourceVideo(for: clip.fileURL)
        }

        guard
            let sharedDuration = sources.map(\.duration).min(),
            sharedDuration > .zero
        else {
            throw VideoPlaybackServiceError.sourceVideoUnavailable
        }

        let composition = AVMutableComposition()
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        let sharedRange = CMTimeRange(
            start: .zero,
            duration: sharedDuration
        )
        let sceneFrame = configuration.sceneFrame
        let destinationFrames = configuration.layout
            .normalizedFrames(for: configuration.sceneOrientation)
            .map { normalizedFrame in
                CGRect(
                    x: sceneFrame.minX + normalizedFrame.minX * sceneFrame.width,
                    y: sceneFrame.minY + normalizedFrame.minY * sceneFrame.height,
                    width: normalizedFrame.width * sceneFrame.width,
                    height: normalizedFrame.height * sceneFrame.height
                )
            }

        var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []

        for (index, source) in sources.enumerated() {
            guard let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw VideoPlaybackServiceError.unableToCreateCompositionTrack
            }

            try compositionVideoTrack.insertTimeRange(
                sharedRange,
                of: source.videoTrack,
                at: .zero
            )

            if index == 0,
               let sourceAudioTrack = try await source.asset
                .loadTracks(withMediaType: .audio)
                .first,
               let audioTrack {
                try audioTrack.insertTimeRange(
                    sharedRange,
                    of: sourceAudioTrack,
                    at: .zero
                )
            }

            let placement = try await VideoCompositionPlacement.make(
                for: source.videoTrack,
                in: destinationFrames[index],
                contentMode: .fill,
                crop: configuration.clipCrops[visibleClips[index].id] ?? VideoClipCrop()
            )
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(
                assetTrack: compositionVideoTrack
            )

            if let sourceCropRect = placement.sourceCropRect {
                layerInstruction.setCropRectangle(
                    sourceCropRect,
                    at: .zero
                )
            }
            layerInstruction.setTransform(placement.transform, at: .zero)
            layerInstructions.append(layerInstruction)
        }

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = sharedRange
        instruction.layerInstructions = layerInstructions
        instruction.backgroundColor = CGColor(gray: 0, alpha: 1)

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = configuration.renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]

        let item = AVPlayerItem(asset: composition)
        item.videoComposition = videoComposition

        return item
    }

    private func makeSourceVideo(
        for url: URL
    ) async throws -> PlaybackSourceVideo {
        let asset = AVURLAsset(url: url)

        guard let videoTrack = try await asset
            .loadTracks(withMediaType: .video)
            .first
        else {
            throw VideoPlaybackServiceError.sourceVideoUnavailable
        }

        let duration = try await asset.load(.duration)

        guard duration.seconds.isFinite, duration.seconds > 0 else {
            throw VideoPlaybackServiceError.sourceVideoUnavailable
        }

        return PlaybackSourceVideo(
            asset: asset,
            videoTrack: videoTrack,
            duration: duration
        )
    }

    private func removeProgressObserver() {
        guard let periodicTimeObserver else {
            return
        }

        queuePlayer.removeTimeObserver(periodicTimeObserver)
        self.periodicTimeObserver = nil
    }
}

private struct PlaybackSourceVideo {
    let asset: AVURLAsset
    let videoTrack: AVAssetTrack
    let duration: CMTime
}

private extension Collection {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values: [T] = []
        values.reserveCapacity(count)

        for element in self {
            let value = try await transform(element)
            values.append(value)
        }

        return values
    }
}

//composition
//→ A, B, C 영상·소리를 시간순으로 이어 둔 원본 타임라인
//
//videoComposition
//→ 각 시간대의 영상을 화면에 어떤 방향으로 그릴지 적은 렌더링 설명서
