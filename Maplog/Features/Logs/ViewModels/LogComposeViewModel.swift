//
//  LogComposeViewModel.swift
//  Maplog
//
//  Created by 한채림 on 8/9/26.
// 사용자가 바꾸는 피드 문구와 커버 시점 관리

import Foundation

@MainActor
final class LogComposeViewModel: ObservableObject {
    @Published var caption = ""
    @Published private(set) var selectedCoverTime: TimeInterval = 0 // 몇 초를 골랐는지
    @Published private(set) var selectedCoverThumbnailData: Data? // 그때의 이미지
    @Published private(set) var isPreviewPlaying = false // 재생 상태
    @Published private(set) var clipLocations: [LogComposeClipLocationDraft]
    @Published private(set) var thumbnailDataByClipID: [UUID: Data] = [:] // 썸네일 상태 함수
    @Published private(set) var isPublishing = false
    @Published private(set) var publishError: ErrorPresentation?
    @Published private(set) var publishedLog: LogPublishResult?

    private let input: LogComposeInput // 편집 화면에서 넘겨받은 변하지 않는 재료
    private let videoPlaybackService: any VideoPlaybackService // 재생 약속을 지키는 객체를 받음
    private let videoThumbnailService: any VideoThumbnailService
    private let logPublishingRepository: any LogPublishingRepository

    init(
        input: LogComposeInput,
        videoPlaybackService: any VideoPlaybackService,
        videoThumbnailService: any VideoThumbnailService,
        logPublishingRepository: any LogPublishingRepository

    ) {
        self.input = input
        self.videoPlaybackService = videoPlaybackService
        self.clipLocations = Self.makeClipLocationDrafts(from: input.clips)
        self.videoThumbnailService = videoThumbnailService
        self.logPublishingRepository = logPublishingRepository

    }

    var video: VideoExportResult {
        input.video
    }

    var clips: [CaptureDraftClip] {
        input.clips
    }

    var videoDurationText: String {
        let totalSeconds = Int(video.duration.rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return String(format: "%02d:%02d", minutes, seconds)
    }

    var clipLocationCountText: String {
        "\(clipLocations.count)개"
    }

    var canPublish: Bool {
        !isPublishing &&
        publishedLog == nil &&
        makePublishDraft() != nil
    }

    func makePublishDraft() -> LogPublishDraft? {
        let captionText = caption.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        var publishClips: [LogPublishClipDraft] = []

        for clipLocation in clipLocations {
            guard let publishClip = makePublishClipDraft(from: clipLocation) else  {
                return nil
            }

            publishClips.append(publishClip)
        }

        guard let representativeAddress = publishClips.first?.location.address else {
            return nil
        }

        let thumbnailTimeMillis: Int?

        if selectedCoverThumbnailData == nil {
                thumbnailTimeMillis = nil
            } else {
                thumbnailTimeMillis = milliseconds(
                    from: selectedCoverTime
                )
            }

        return LogPublishDraft(
                videoFileURL: video.fileURL,
                caption: captionText,
                representativeAddress: representativeAddress,
                thumbnailTimeMillis: thumbnailTimeMillis,
                clips: publishClips
            )
    }

    func publish() async {
        guard
            !isPublishing,
            let draft = makePublishDraft()
        else {
            return
        }

        isPublishing = true
        publishError = nil
        stopPreview()

        defer {
            isPublishing = false
        }

        do {
            let result = try await logPublishingRepository.publish(
                draft: draft
            )

            guard !Task.isCancelled else {
                return
            }

            publishedLog = result
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else {
                return
            }

            publishError = LogPublishErrorPolicy.presentation(
                for: error
            )
        }
    }

    func dismissPublishError() {
        publishError = nil
    }

    func dismissPublishedLog() {
        publishedLog = nil
    }

    func thumbnailData(for clipID: UUID) -> Data? {
        thumbnailDataByClipID[clipID]
    }

    func clipLocation(
        for id: UUID
    ) -> LogComposeClipLocationDraft? {
        clipLocations.first(
            where: { $0.id == id }
        )
    }

    func updateClipLocation(
        _ updatedClipLocation: LogComposeClipLocationDraft
    ) {
        guard let index = clipLocations.firstIndex(
            where: { $0.id == updatedClipLocation.id }
        ) else {
            return
        }

        clipLocations[index] = updatedClipLocation
    }

    func timeRangeText(
        for clipLocation: LogComposeClipLocationDraft
    ) -> String {
        "\(timelineTimeText(clipLocation.startTime))–\(timelineTimeText(clipLocation.endTime))"
    }

    func locationText(
        for clipLocation: LogComposeClipLocationDraft
    ) -> String {
        guard let location = clipLocation.location else {
            return "장소를 선택해 주세요"
        }

        return location.name ?? "촬영 위치"
    }

    private static func makeClipLocationDrafts(
        from clips: [CaptureDraftClip]
    ) -> [LogComposeClipLocationDraft] {
        let timeline = ClipEditorTimeline(clips: clips)

        return timeline.segments.compactMap { segment in
            guard let clip = clips.first(
                where: { $0.id == segment.clipID }
            ) else {
                return nil
            }

            return LogComposeClipLocationDraft(
                clipID: clip.id,
                videoURL: clip.fileURL,
                startTime: segment.startTime,
                endTime: segment.endTime,
                location: clip.location.map(LogLocationDraft.init)
            )
        }
    }

    func selectCover(_ frame: LogCoverFrame) {
        let selectedTime = min(
                max(frame.time, 0),
                video.duration
            )

        selectedCoverTime = selectedTime
        selectedCoverThumbnailData = frame.thumbnailData

        videoPlaybackService.loadVideo(at: video.fileURL)
        isPreviewPlaying = false
    }

    // 커버 선택 화면용 입력값
    func makeCoverSelectionInput() -> LogCoverSelectionInput {
        LogCoverSelectionInput(videoURL: video.fileURL, duration: video.duration, initialSelectedTime: selectedCoverTime)
    }

    func prepare() async {
        preparePreview()
        await loadClipLocationThumbnails()
    }

    // 재생 함수
    func preparePreview() {
        videoPlaybackService.loadVideo(at: video.fileURL)
        isPreviewPlaying = false
    }

    func togglePreviewPlayback() {
        if isPreviewPlaying {
            videoPlaybackService.pause()
        } else {
            videoPlaybackService.play()
        }

        isPreviewPlaying.toggle()
    }

    func stopPreview() {
        videoPlaybackService.stop()
        isPreviewPlaying = false
    }

    private func loadClipLocationThumbnails() async {
        for clipLocation in clipLocations {
            guard !Task.isCancelled else {
                return
            }

            do {
                let thumbnailData = try await videoThumbnailService
                    .makeThumbnailData(for: clipLocation.videoURL)

                guard !Task.isCancelled else {
                    return
                }

                thumbnailDataByClipID[clipLocation.id] = thumbnailData
            } catch {
                // 썸네일은 보조 UI이므로 실패해도 기본 아이콘 카드로 표시한다.
            }
        }
    }

    private func timelineTimeText(
        _ seconds: TimeInterval
    ) -> String {
        let totalSeconds = Int(seconds.rounded(.down))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60

        return String(
            format: "%02d:%02d",
            minutes,
            remainingSeconds
        )
    }

    private func makePublishClipDraft(
        from clipLocation: LogComposeClipLocationDraft
    ) -> LogPublishClipDraft? {
        guard
            let location = clipLocation.location,
            let address = normalizedText(location.address)
        else {
            return nil
        }

        let startTimeMillis = milliseconds(
            from: max(clipLocation.startTime, 0)
        )

        let endTimeMillis = milliseconds(
            from: min(clipLocation.endTime, video.duration)
        )

        guard endTimeMillis > startTimeMillis else {
            return nil
        }

        return LogPublishClipDraft(
            location: LogPublishLocationDraft(
                name: normalizedText(location.name),
                address: address,
                latitude: location.latitude,
                longitude: location.longitude
            ),
            startTimeMillis: startTimeMillis,
            endTimeMillis: endTimeMillis
        )
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

    private func milliseconds(
        from seconds: TimeInterval
    ) -> Int {
        Int((seconds * 1_000).rounded())
    }
}
