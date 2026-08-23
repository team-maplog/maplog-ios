//
//  VideoPlaybackService.swift
//  Maplog
//
//  Created by 한채림 on 8/2/26.
// 재생 기능의 약속, URL의 영상 준비해, 재생해라고 Service에 요청
 
import AVFoundation
import Foundation

@MainActor
protocol VideoPlaybackService: AnyObject {
    var player: AVPlayer { get }
    var isMuted: Bool { get } // 음소거 기능
    
    func loadVideo(at url: URL) // 단일 영상이나 완성본 미리보기용

    func loadVideoSequence( // A→B→C 편집 미리보기용
        from urls: [URL]
    ) async throws

    func seek(
        to seconds: TimeInterval
    )

    func seek(
        to seconds: TimeInterval,
        completion: @escaping @Sendable (Bool) -> Void
    )

    func toggleMute() // AVQueuePlayer가 실제 소리를 내는 객체라서, 음소거 기술 처리는 Service
    func play()
    func pause()
    func stop()
    func observeProgress(
        _ handler: @escaping (Double) -> Void
    )
}
