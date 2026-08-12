//
//  LogCoverSelectionViewModel.swift
//  Maplog
//
//  Created by 한채림 on 8/12/26.
// 커버 선택

import Foundation

@MainActor
final class LogCoverSelectionViewModel: ObservableObject {
    @Published private(set) var frames: [LogCoverFrame] = []
    @Published private(set) var selectedTime: TimeInterval
    @Published private(set) var isLoading = false
    @Published private(set) var errorPresentation: ErrorPresentation?

    private let input: LogCoverSelectionInput
    private let videoThumbnailService: any VideoThumbnailService

    init(
            input: LogCoverSelectionInput,
            videoThumbnailService: any VideoThumbnailService
        ) {
            self.input = input
            self.videoThumbnailService = videoThumbnailService
            self.selectedTime = input.initialSelectedTime
        }

    var selectedFrame: LogCoverFrame? {
            frames.first {
                $0.time == selectedTime
            }
        }

    func loadFrames() async {
        isLoading = true
        errorPresentation = nil

        let times = frameTimes(duration: input.duration) // 영상 전체에서 7개 시점으로 균등하게 배분 했을 때의 시간

        frames = times.map {
            LogCoverFrame(time: $0, thumbnailData: nil)
        }

        do {
            for time in times {
                guard !Task.isCancelled else {
                    return
                }

                let thumbnailData = try await videoThumbnailService.makeThumbnailData(for: input.videoURL, at: time)

                guard !Task.isCancelled, let index = frames.firstIndex(where: { $0.time == time }
                )
                else {
                    return
                }

                frames[index].thumbnailData = thumbnailData
            }

            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            isLoading = false
            errorPresentation = LogCoverSelectionErrorPolicy.presentation(for: error)
        }
    }

    func selectFrame(at time: TimeInterval) {
        selectedTime = time
    }

    func retry() async {
        await loadFrames()
    }

    private func frameTimes(duration: TimeInterval) -> [TimeInterval] {
        let frameCount = 7

        guard duration > 0 else {
            return [0]
        }

        let interval = duration / Double(frameCount - 1)

        return (0..<frameCount).map { index in
            min(Double(index) * interval, duration)
        }
    }
}
