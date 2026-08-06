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

    var player: AVPlayer {
        queuePlayer
    }

    var isMuted: Bool {
        queuePlayer.isMuted
    }

    func toggleMute() {
        queuePlayer.isMuted.toggle()
    }

    func loadVideo(at url: URL) {
        stop()

        let templateItem = AVPlayerItem(url: url)

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
        let safeSeconds = max(seconds, 0)

        let time = CMTime(
            seconds: safeSeconds,
            preferredTimescale: 600
        )

        queuePlayer.seek(to: time)
    }

    func play() {
        queuePlayer.play()
    }

    func pause() {
        queuePlayer.pause()
    }

    func stop() {
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
        from urls: [URL]
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

        for url in urls {
            print("영상 준비 시작:", url.lastPathComponent)
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

            layerInstruction.setTransform( // 아이폰 영상은 실제 픽셀 데이터는 가로인데, “세로로 돌려서 보여 줘”라는 회전 정보
                preferredTransform,
                at: insertionTime
            )

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

    private func removeProgressObserver() {
        guard let periodicTimeObserver else {
            return
        }

        queuePlayer.removeTimeObserver(periodicTimeObserver)
        self.periodicTimeObserver = nil
    }
}

//composition
//→ A, B, C 영상·소리를 시간순으로 이어 둔 원본 타임라인
//
//videoComposition
//→ 각 시간대의 영상을 화면에 어떤 방향으로 그릴지 적은 렌더링 설명서
