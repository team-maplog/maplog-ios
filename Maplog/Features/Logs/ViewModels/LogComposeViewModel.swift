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
    @Published private(set) var isResolvingClipLocations = false
    @Published private(set) var locationResolutionError: ErrorPresentation?
    /// Maplog 발행과 사진 앱 저장은 한 번에 하나만 처리합니다.
    @Published private(set) var isPerformingPublicationAction = false
    @Published private(set) var isPublishingToMaplog = false
    @Published private(set) var publishError: ErrorPresentation?
    @Published private(set) var publicationCompletion: LogPublicationCompletion?

    /// 결과를 확인하지 못한 동일 초안의 재시도에만 유지합니다.
    private var pendingMaplogPublishAttempt: LogPublishAttempt?

    private let input: LogComposeInput // 편집 화면에서 넘겨받은 변하지 않는 재료
    private let videoPlaybackService: any VideoPlaybackService // 재생 약속을 지키는 객체를 받음
    private let videoThumbnailService: any VideoThumbnailService
    private let logLocationRepository: any LogLocationRepository
    private let logPublishingRepository: any LogPublishingRepository
    private let photoLibraryVideoSaveService: any PhotoLibraryVideoSaving

    init(
        input: LogComposeInput,
        videoPlaybackService: any VideoPlaybackService,
        videoThumbnailService: any VideoThumbnailService,
        logLocationRepository: any LogLocationRepository,
        logPublishingRepository: any LogPublishingRepository,
        photoLibraryVideoSaveService: any PhotoLibraryVideoSaving

    ) {
        self.input = input
        self.videoPlaybackService = videoPlaybackService
        self.clipLocations = Self.makeClipLocationDrafts(
            from: input.clips,
            compositionConfiguration: input.compositionConfiguration,
            finalVideoDuration: input.video.duration
        )
        self.videoThumbnailService = videoThumbnailService
        self.logLocationRepository = logLocationRepository
        self.logPublishingRepository = logPublishingRepository
        self.photoLibraryVideoSaveService = photoLibraryVideoSaveService

    }

    var video: VideoExportResult {
        input.video
    }

    var clips: [CaptureDraftClip] {
        input.clips
    }

    var compositionConfiguration: VideoCompositionConfiguration {
        input.compositionConfiguration
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

    var hashtags: [String] {
        parsedHashtags.tags
    }

    var hashtagValidationMessage: String? {
        parsedHashtags.validationMessage
    }

    var hashtagCountText: String {
        "\(hashtags.count)/\(LogCustomTagParser.maximumTagCount)"
    }

    var hashtagPreviewText: String {
        hashtags.map { "#\($0)" }.joined(separator: " ")
    }

    var canPublishToMaplog: Bool {
        !isPerformingPublicationAction
            && !isResolvingClipLocations
            && makePublishDraft() != nil
    }

    var canRetryLocationResolution: Bool {
        !isResolvingClipLocations
            && locationResolutionError?.recoveryAction == .retry
    }

    var maplogPublicationBlockMessage: String? {
        if isResolvingClipLocations {
            return "촬영 위치를 확인하고 있어요. 잠시만 기다려 주세요."
        }

        if let hashtagValidationMessage {
            return hashtagValidationMessage
        }

        if !isValidSelectedCoverTime {
            return "선택한 커버 시점을 확인해 주세요."
        }

        if let locationResolutionError {
            return locationResolutionError.message
        }

        guard makePublishDraft() == nil else {
            return nil
        }

        return "위치 정보가 없는 클립이 있어요. Maplog 발행에는 촬영 위치가 필요해요."
    }

    func makePublishDraft() -> LogPublishDraft? {
        let captionText = caption.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let parsedTags = parsedHashtags

        guard
            parsedTags.validationMessage == nil,
            isValidSelectedCoverTime
        else {
            return nil
        }

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
            tags: parsedTags.tags,
            representativeAddress: representativeAddress,
            thumbnailTimeMillis: thumbnailTimeMillis,
            clips: publishClips
        )
    }

    /// Maplog에만 로그를 발행합니다. 사진 앱 저장·공유와 결합하지 않아
    /// 화면의 각 행동이 하나의 결과만 만들도록 합니다.
    func publishToMaplog() async {
        guard canPublishToMaplog, let draft = makePublishDraft() else {
            return
        }
        let attempt = maplogPublishAttempt(for: draft)

        isPerformingPublicationAction = true
        isPublishingToMaplog = true
        publishError = nil
        stopPreview()

        defer {
            isPerformingPublicationAction = false
            isPublishingToMaplog = false
        }

        do {
            let publishedLog = try await logPublishingRepository.publish(
                attempt: attempt
            )

            // 서버가 SUCCESS-001 또는 SUCCESS-008로 응답한 확정 성공입니다.
            pendingMaplogPublishAttempt = nil

            guard !Task.isCancelled else {
                return
            }

            publicationCompletion = LogPublicationCompletion(
                publishedLog: publishedLog,
                savedToPhotoLibrary: false
            )
        } catch is CancellationError {
            return
        } catch {
            // 타임아웃·연결 종료처럼 결과를 확정할 수 없을 때만 같은 키를 남깁니다.
            pendingMaplogPublishAttempt = shouldReusePublishAttempt(after: error)
                ? attempt
                : nil
            presentPublicationErrorIfNeeded(error)
        }
    }

    /// 완성 영상을 사진 앱에만 저장합니다. Maplog 발행 요청은 만들지 않습니다.
    func saveToPhotoLibrary() async {
        guard !isPerformingPublicationAction else {
            return
        }

        isPerformingPublicationAction = true
        publishError = nil
        stopPreview()

        defer {
            isPerformingPublicationAction = false
        }

        do {
            try await photoLibraryVideoSaveService.saveVideo(
                at: video.fileURL
            )

            guard !Task.isCancelled else {
                return
            }

            publicationCompletion = LogPublicationCompletion(
                publishedLog: nil,
                savedToPhotoLibrary: true
            )
        } catch is CancellationError {
            return
        } catch {
            presentPublicationErrorIfNeeded(error)
        }
    }

    func dismissPublishError() {
        publishError = nil
    }

    func dismissPublicationCompletion() {
        publicationCompletion = nil
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

        if clipLocations.allSatisfy({
            normalizedText($0.location?.address) != nil
        }) {
            locationResolutionError = nil
        }
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
            return "촬영 위치 정보 없음"
        }

        if location.address == nil, isResolvingClipLocations {
            return "촬영 위치를 찾는 중이에요"
        }

        return location.name ?? "촬영 위치"
    }

    private static func makeClipLocationDrafts(
        from clips: [CaptureDraftClip],
        compositionConfiguration: VideoCompositionConfiguration,
        finalVideoDuration: TimeInterval
    ) -> [LogComposeClipLocationDraft] {
        let timeline = ClipEditorTimeline(
            clips: clips,
            compositionConfiguration: compositionConfiguration
        )

        guard let publicationTimeRanges = LogPublicationTimeline.makeTimeRanges(
            sourceDurations: timeline.segments.map(\.duration),
            finalVideoDuration: finalVideoDuration
        ) else {
            return []
        }

        return zip(timeline.segments, publicationTimeRanges).compactMap {
            segment,
            publicationTimeRange in
            guard let clip = clips.first(
                where: { $0.id == segment.clipID }
            ) else {
                return nil
            }

            return LogComposeClipLocationDraft(
                clipID: clip.id,
                videoURL: clip.fileURL,
                startTime: publicationTimeRange.startTime,
                endTime: publicationTimeRange.endTime,
                location: clip.location.map(LogLocationDraft.init)
            )
        }
    }

    func selectCover(_ frame: LogCoverFrame) {
        // `thumbnailTimeMillis`는 영상의 마지막 시점과 같을 수 없습니다.
        // 밀리초 단위로 1ms 앞까지만 선택 범위에 넣습니다.
        let latestSelectableTime = max(video.duration - 0.001, 0)
        let selectedTime = min(
            max(frame.time, 0),
            latestSelectableTime
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
        async let thumbnails: Void = loadClipLocationThumbnails()
        async let locations: Void = resolveCapturedClipLocations()

        _ = await (thumbnails, locations)
    }

    /// 주소 조회가 실패했을 때 같은 촬영 좌표로 다시 조회합니다.
    /// 로그 생성 API는 모든 클립의 주소가 있어야 하므로, 성공 전까지 발행은 막습니다.
    func retryLocationResolution() async {
        guard !isResolvingClipLocations else {
            return
        }

        await resolveCapturedClipLocations()
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

    /// 카메라가 저장한 위도·경도는 그대로 살리고, 서버의 위치 API로 주소만
    /// 채운다. 사용자가 위치 카드를 열어 수정하지 않아도 발행할 수 있게 하는 단계다.
    private func resolveCapturedClipLocations() async {
        let unresolvedLocations = clipLocations.filter { clipLocation in
            guard let location = clipLocation.location else {
                return false
            }

            return normalizedText(location.address) == nil
        }

        guard !unresolvedLocations.isEmpty else {
            locationResolutionError = nil
            return
        }

        isResolvingClipLocations = true
        locationResolutionError = nil
        defer {
            isResolvingClipLocations = false
        }

        for clipLocation in unresolvedLocations {
            guard
                !Task.isCancelled,
                let location = clipLocation.location
            else {
                return
            }

            do {
                let resolvedLocation = try await logLocationRepository
                    .resolveLocation(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )

                guard
                    !Task.isCancelled,
                    let index = clipLocations.firstIndex(
                        where: { $0.id == clipLocation.id }
                    ),
                    let currentLocation = clipLocations[index].location,
                    normalizedText(currentLocation.address) == nil
                else {
                    continue
                }

                clipLocations[index].location = LogLocationDraft(
                    latitude: resolvedLocation.latitude,
                    longitude: resolvedLocation.longitude,
                    name: resolvedLocation.name ?? currentLocation.name,
                    address: resolvedLocation.address
                )
            } catch is CancellationError {
                return
            } catch {
                // 주소가 없는 클립은 발행할 수 없으므로 실패 이유와 재시도 동작을
                // 화면에 남긴다. 이미 주소를 찾은 다른 클립은 그대로 유지한다.
                locationResolutionError = LogLocationErrorPolicy
                    .presentation(for: error)
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

    private var parsedHashtags: LogCustomTagParseResult {
        LogCustomTagParser.parse(caption: caption)
    }

    /// 서버는 `thumbnailTimeMillis`가 최종 영상 길이보다 작을 때만 받습니다.
    /// 커버를 고르지 않은 경우에는 키 자체를 생략하므로 유효합니다.
    private var isValidSelectedCoverTime: Bool {
        guard selectedCoverThumbnailData != nil else {
            return true
        }

        let durationMillis = milliseconds(from: video.duration)
        let selectedMillis = milliseconds(from: selectedCoverTime)

        return durationMillis > 0
            && selectedMillis >= 0
            && selectedMillis < durationMillis
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

    private func maplogPublishAttempt(
        for draft: LogPublishDraft
    ) -> LogPublishAttempt {
        if let pendingMaplogPublishAttempt,
           pendingMaplogPublishAttempt.isForSameDraft(draft)
        {
            return pendingMaplogPublishAttempt
        }

        pendingMaplogPublishAttempt = nil
        return LogPublishAttempt(draft: draft)
    }

    /// 이 경우들은 서버가 로그를 만들었는지 앱이 확정할 수 없다.
    private func shouldReusePublishAttempt(
        after error: Error
    ) -> Bool {
        guard let apiError = error as? APIError else {
            return false
        }

        switch apiError {
        case .network,
             .invalidResponse,
             .decoding,
             .missingData:
            return true

        default:
            return false
        }
    }

    private func publicationErrorPresentation(
        for error: Error
    ) -> ErrorPresentation {
        if error is PhotoLibraryVideoSaveError {
            return ErrorPresentation(
                message: error.localizedDescription,
                recoveryAction: .retry
            )
        }

        return LogPublishErrorPolicy.presentation(for: error)
    }

    private func presentPublicationErrorIfNeeded(
        _ error: Error
    ) {
        guard !Task.isCancelled else {
            return
        }

        publishError = publicationErrorPresentation(for: error)
    }
}
