//
//  ClipEditorViewModel.swift
//  Maplog
//
//  Created by 한채림 on 8/2/26.
// 선택된 클립 → 타임라인에 그릴 화면 데이터로 변환

import Foundation

@MainActor
final class ClipEditorViewModel: ObservableObject {
    @Published private(set) var state: ClipEditorState = .loading
    @Published private(set) var timelineItems: [ClipEditorTimelineItemViewData] = [] // View가 그릴 타임라인 카드 목록
    @Published private(set) var selectedPreview: ClipEditorTimelineItemViewData? // 상단 미리보기에 현재 보여 줄 클립 카드 데이터
    @Published private(set) var playbackProgress: Double = 0
    @Published private(set) var isExporting = false
    @Published private(set) var exportedVideo: VideoExportResult?
    @Published private(set) var exportError: ErrorPresentation?
    @Published private(set) var textOverlays: [ClipTextOverlay] = [] // 자막 상태 프로퍼티, 최종 영상에 들어갈 편집 데이터라서 ClipTextOverlay Model 그대로 보관
    @Published private(set) var playingClipID: UUID?
    @Published private(set) var playingLocalTime: TimeInterval = 0
    
    
    private let input: ClipEditorInput // Clip Picker에서 넘겨준 선택 결과, 실제 CaptureDraftClip들이 있고, 각 클립의 파일 URL·촬영 날짜·길이가 들어있음
    private let videoThumbnailService: any VideoThumbnailService // 영상 파일 URL로부터 썸네일 Data를 만드는 기술 담당
    private var orderedClips: [CaptureDraftClip] = [] // 나중에 실제로 이어붙일 원본 영상들의 현재 순서
    private var editorTimeline = ClipEditorTimeline(clips: [])
    private var hasPrepared = false // .task가 예상치 않게 다시 실행돼 편집 순서가 초기화되는 것을 막아줌
    private let videoPlaybackService: any VideoPlaybackService
    private let videoExportService: any VideoExportService
    private var sequenceReloadTask: Task<Void, Never>? // 빠르게 여러 번 드래그했을 때, 이전 순서로 만드는 작업을 취소하고 가장 마지막 순서만 반영하기 위한 프로퍼티
    
    init(
        input: ClipEditorInput,
        videoThumbnailService: any VideoThumbnailService,
        videoPlaybackService: any VideoPlaybackService,
        videoExportService: any VideoExportService
    ) {
        self.input = input
        self.videoThumbnailService = videoThumbnailService
        self.videoPlaybackService = videoPlaybackService
        self.videoExportService = videoExportService
    }
    
    
//    Picker 선택: [B, A, C]
//    input.clips: [B, A, C]
//    orderedClips: [B, A, C]
//    timelineItems: [B 카드, A 카드, C 카드]
    func prepare() async {
        guard !hasPrepared else {
            return
        }
        
        hasPrepared = true
        state = .loading
        
        orderedClips = input.clips
        
        editorTimeline = ClipEditorTimeline( // A,B,C 전체 Schedule을 만듦
            clips: orderedClips
        )
        
        timelineItems = orderedClips.map { clip in
            makeTimelineItemViewData(from: clip)
        }
        
        guard let firstVideoClip = orderedClips.first(
            where: { $0.mediaType == .video }
        ) else {
            state = .failed(
                ErrorPresentation(
                    message: "편집할 영상이 없어요.",
                    recoveryAction: .none
                )
            )
            return
        }
        
        do {
            try await loadSequencePreview() // 실제 A-B-C 영상을 AVPlayer에 준비
            
            guard !Task.isCancelled else {
                return
            }
            
            selectPreview( // 자동 재생 설정
                id: firstVideoClip.id,
                shouldPlay: true
            )
            
            state = .content
            
            await loadThumbnails(
                for: orderedClips
            )
        } catch {
            guard !Task.isCancelled else {
                return
            }
            
            hasPrepared = false
            
            state = .failed(
                ClipEditorErrorPolicy.playbackPresentation(
                    for: error
                )
            )
        }
    }
    func timelineOrder(for id: UUID) -> Int? {
        guard let index = timelineItems.firstIndex(where: { $0.id == id }
        ) else {
            return nil
        }
        
        return index + 1
    }
    
    // 실제 영상 준비 + 화면 상태 변경 함수 추가
    func selectPreview(
        id: UUID,
        shouldPlay: Bool = true
    ) {
        guard
                let timelineItem = timelineItems.first( // 예) B 카드의 썸네일·표시용 정보, 사용자가 탭한 바로 그 카드
                    where: { $0.id == id }
                ),
                let segment = editorTimeline.segments.first( // B는 전체 영상의 2.0초 ~ 4.0초 구간이라는 재생용 정보, segment.clipID(검사 중인 A/B/C 구간의 원래 클립 ID)와 함수 매개변수 id를 비교
                    where: { $0.clipID == id }
                )
            else {
                return
            }

        selectedPreview = timelineItem // 상단 화면에 썸네일·길이 표시
        
        movePlayback(
                to: segment.startTime
            )

            if shouldPlay {
                videoPlaybackService.play()
            }
    }
    
    func stopPreview() {
        videoPlaybackService.stop()
        
        playbackProgress = 0
        playingClipID = nil
        playingLocalTime = 0
    }
    
    func exportVideo() async {
        guard !orderedClips.isEmpty, !isExporting else {
            return
        }
        
        isExporting = true
        exportError = nil
        exportedVideo = nil
        
        videoPlaybackService.pause()
        
        defer {
            isExporting = false
        }
        
        do {
            let request = VideoExportRequest(
                clips: orderedClips,
                textOverlays: textOverlays
            )
            
            let result = try await videoExportService.export(
                request: request
            )
            
            guard !Task.isCancelled else {
                        return
                    }
            
            exportedVideo = result
        } catch {
            guard !Task.isCancelled else {
                return
            }
            
            exportError = ClipEditorErrorPolicy.exportPresentation(for: error)
        }
    }
    
    func textOverlays(for clipID: UUID) -> [ClipTextOverlay] {
        textOverlays
            .filter { $0.clipID == clipID }
            .sorted { $0.startTime < $1.startTime }
    }
    
    // ViewModel에서 변환
    func textOverlayItems(
        for clipID: UUID
    ) -> [ClipTextOverlayItemViewData] {
        textOverlays(for: clipID).map { overlay in
            ClipTextOverlayItemViewData(
                id: overlay.id,
                text: overlay.text,
                displayTimeText: overlayTimeText(
                    for: overlay
                )
            )
        }
    }
    // view는 아래와 같은 데이터만 받게 됨. 
    // ClipTextOverlayItemViewData(
//    id: ...,
//    text: "부산 해운대",
//    displayTimeText: "1.2초 ~ 3.2초"
//)

    private func overlayTimeText(
        for overlay: ClipTextOverlay
    ) -> String {
        "\(formattedSeconds(overlay.startTime))초 ~ "
        + "\(formattedSeconds(overlay.endTime))초"
    }

    private func formattedSeconds(
        _ seconds: TimeInterval
    ) -> String {
        String(format: "%.1f", seconds)
    }
    
    
    
//    5초짜리 A 클립
//    현재 1.3초 재생 중
//    → 새 자막: 1.3초 ~ 3.3초
//
//    현재 4.7초 재생 중
//    → 새 자막: 3초 ~ 5초
    func addTextOverlay(
        to clipID: UUID,
        text: String
    ) {
        let trimmedText = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard
            !trimmedText.isEmpty,
            let clip = orderedClips.first(
                where: { $0.id == clipID && $0.mediaType == .video }
            ),
            let duration = clip.duration,
            duration > 0
        else {
            return
        }

        let overlayDuration = min(2, duration)

        let currentTime: TimeInterval

        if playingClipID == clipID { // 전체 영상 4.3초가 아니라 지금 재생 중인 B 클립의 2.3초를 기준으로 추가
            currentTime = playingLocalTime
        } else {
            currentTime = 0
        }

        let latestStartTime = max(0, duration - overlayDuration)
        let startTime = min(currentTime, latestStartTime)
        let endTime = min(startTime + overlayDuration, duration)

        let overlay = ClipTextOverlay(
            clipID: clipID,
            text: trimmedText,
            startTime: startTime,
            endTime: endTime
        )

        textOverlays.append(overlay)
    }
    
    func updateTextOverlay(
        id: UUID,
        text: String
    ) {
        let trimmedText = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard
            !trimmedText.isEmpty,
            let index = textOverlays.firstIndex(
                where: { $0.id == id }
            )
        else {
            return
        }

        textOverlays[index].text = trimmedText
    }

    func deleteTextOverlay(id: UUID) {
        textOverlays.removeAll { $0.id == id }
    }
    
    func playExportedVideo(
        _ result: VideoExportResult
    ) {
        videoPlaybackService.stop()
        playbackProgress = 0

        videoPlaybackService.loadVideo(
            at: result.fileURL
        )

        videoPlaybackService.play()
    }
    
    private func makeTimelineItemViewData(from clip: CaptureDraftClip) -> ClipEditorTimelineItemViewData {
        ClipEditorTimelineItemViewData(id: clip.id, thumbnailData: nil, durationText: durationText(for: clip)
        )
    }
    
    func restoreSelectedPreview() async {
        editorTimeline = ClipEditorTimeline( // Picker를 닫을 때 새 타임라인 기준으로 다시 재생
            clips: orderedClips
        )
        guard let selectedID = selectedPreview?.id else {
            stopPreview()
            return
        }

        do {
            try await loadSequencePreview() // 편집용 A → B → C 연결 영상을 넣음

            selectPreview( // 자동 재생 설정
                id: selectedID,
                shouldPlay: true
            )
        } catch {
            guard !Task.isCancelled else {
                return
            }

            state = .failed(
                ClipEditorErrorPolicy.playbackPresentation(
                    for: error
                )
            )
        }
    }
    
    private func durationText(for clip: CaptureDraftClip) -> String {
        guard clip.mediaType == .video,
              let duration = clip.duration
        else {
            return "사진"
        }
        
        return "\(max(1, Int(duration.rounded())))초"
    }
    
    private func loadThumbnails(for clips: [CaptureDraftClip]
    ) async {
        for clip in clips where clip.mediaType == .video {
            let thumbnailData = try? await videoThumbnailService
                .makeThumbnailData(for: clip.fileURL)
            
            guard !Task.isCancelled else {
                return
            }
            
            guard let index = timelineItems.firstIndex(where: { $0.id == clip.id }
            ) else {
                continue
            }
            
            timelineItems[index].thumbnailData = thumbnailData
            
            if selectedPreview?.id == clip.id {
                selectedPreview = timelineItems[index]
            }
        }
    }
    
    var editingClipIDs: Set<UUID> { // 지금 편집기에 포함된 클립 ID 모음, + 선택 화면에서 중복 클립을 숨기는 데 사용
        Set(
            orderedClips.map(\.id)
        )
    }
    
    // 현재 편집 순서를 외부에 전달할 프로퍼티
    var editingClipIDsInOrder: [UUID] {
        orderedClips.map(\.id)
    }
    
    // 삭제 순서 변경 행동
    var canRemoveClip: Bool {
        orderedClips.count > 1
    }
    
    // 클립 제외 뒤에도 재생 순서 갱신
    func removeClip(id: UUID) {
        guard canRemoveClip,
              let index = orderedClips.firstIndex(
                where: { $0.id == id }
              )
        else {
            return
        }

        let removedSelectedClip = selectedPreview?.id == id

        orderedClips.remove(at: index)
        timelineItems.remove(at: index)

        textOverlays.removeAll {
            $0.clipID == id
        }

        let preferredSelectionID: UUID?

        if removedSelectedClip {
            if orderedClips.indices.contains(index) {
                preferredSelectionID = orderedClips[index].id
            } else {
                preferredSelectionID = orderedClips.last?.id
            }
        } else {
            preferredSelectionID = selectedPreview?.id
        }

        refreshSequencePreview(
            preferredSelectionID: preferredSelectionID
        )
    }
    
//    1. Picker 선택 순서 그대로 finalClips 생성
//    2. 중복 ID 제거
//    3. 기존 orderedClips를 finalClips로 교체
//    4. 이미 있던 카드 썸네일은 유지
//    5. 새로 추가된 클립만 썸네일 생성
//    6. 편집에서 빠진 클립의 자막만 제거
//    7. 기존 선택 클립이 남아 있으면 그 선택 유지
//    8. 없어졌다면 첫 번째 클립 선택
//    기존: A → B → C
//    자막: A 자막, B 자막, C 자막
//
//    새 선택: A → C → D
//
//    결과:
//    orderedClips = [A, C, D]
//    자막 = [A 자막, C 자막]
    func applyClipSelection(
        _ clips: [CaptureDraftClip]
    ) {
        var handledIDs = Set<UUID>()

        let finalClips = clips.filter { clip in
            guard clip.mediaType == .video else {
                return false
            }

            return handledIDs.insert(clip.id).inserted
        }

        guard !finalClips.isEmpty else {
            return
        }

        let previousClipIDs = Set(
            orderedClips.map(\.id)
        )

        let previousItemsByID = Dictionary(
            uniqueKeysWithValues: timelineItems.map {
                ($0.id, $0)
            }
        )

        let remainingClipIDs = Set(
            finalClips.map(\.id)
        )

        let previousSelectedID = selectedPreview?.id

        orderedClips = finalClips

        editorTimeline = ClipEditorTimeline(
            clips: finalClips
        )

        timelineItems = finalClips.map { clip in
            previousItemsByID[clip.id]
            ?? makeTimelineItemViewData(from: clip)
        }

        textOverlays.removeAll { overlay in
            !remainingClipIDs.contains(overlay.clipID)
        }

        let selectedID: UUID?

        if
            let previousSelectedID,
            remainingClipIDs.contains(previousSelectedID)
        {
            selectedID = previousSelectedID
        } else {
            selectedID = finalClips.first?.id
        }

        selectedPreview = timelineItems.first {
            $0.id == selectedID
        }

        let newlyAddedClips = finalClips.filter {
            !previousClipIDs.contains($0.id)
        }

        Task { [weak self] in
            guard let self else {
                return
            }

            await self.loadThumbnails(
                for: newlyAddedClips
            )
        }
    }
    
    
    
    
    func canMoveClipEarlier(id: UUID) -> Bool {
        guard let index = orderedClips.firstIndex(where: { $0.id == id }) else {
            return false
        }
        
        return index > 0
        }
        
    func canMoveClipLater(id: UUID) -> Bool {
        guard let index = orderedClips.firstIndex(where: { $0.id == id }) else {
            return false
        }
        // 현재 클립이 마지막 클립보다 앞에 있으면, 뒤로 이동할 수 있음 true false
        return index < orderedClips.count - 1
    }
    
    func moveClipEarlier(id: UUID) {
        guard let index = orderedClips.firstIndex(where: { $0.id == id }) else {
            return
        }

        guard index > 0 else {
            return
        }

        // 앞으로 이동
        orderedClips.swapAt(index, index - 1)
        timelineItems.swapAt(index, index - 1)
        
        refreshSequencePreview(
            preferredSelectionID: selectedPreview?.id
        )
    }
    
    func moveClipLater(id: UUID) {
        guard let index = orderedClips.firstIndex(where: { $0.id == id }) else {
            return
        }

        guard index < orderedClips.count - 1 else {
            return
        }
        
        //        [B, A, C]
        //        B를 뒤로 이동
        //        → [A, B, C]
        orderedClips.swapAt(index, index + 1)
        timelineItems.swapAt(index, index + 1)
        
        refreshSequencePreview(
            preferredSelectionID: selectedPreview?.id
        )
    }
    
//    B 카드를 길게 누르고 C 위치까지 드래그
//    → Timeline View가 “B를 C 위치로 옮겨줘” 전달
//    → ViewModel이 orderedClips와 timelineItems를 같은 순서로 이동
//    → 타임라인 번호와 최종 영상 연결 순서가 함께 변경
    func moveClip(id: UUID, to targetID: UUID) {
        guard id != targetID,
              let sourceIndex = orderedClips.firstIndex(where: { $0.id == id }
              ),
              let targetIndex = orderedClips.firstIndex(where: { $0.id == targetID })
        else {
             return
        }
        
        let movingClip = orderedClips.remove(at: sourceIndex)
        let movingItem = timelineItems.remove(at: sourceIndex)
        
        orderedClips.insert(movingClip, at: targetIndex)
        timelineItems.insert(movingItem, at: targetIndex)
        
        refreshSequencePreview(
            preferredSelectionID: selectedPreview?.id
        )
    }

    private func loadSequencePreview() async throws {
        let videoURLs = orderedClips
            .filter { $0.mediaType == .video }
            .map(\.fileURL)

        try await videoPlaybackService.loadVideoSequence(
            from: videoURLs
        )

        videoPlaybackService.observeProgress { [weak self] progress in
            guard let self else {
                return
            }

            self.playbackProgress = progress

            let globalTime = progress
                * self.editorTimeline.totalDuration

            self.updatePlayingPosition(
                for: globalTime
            )
        }
    }
    
    // 타임라인 변경 뒤 재생기를 다시 만드는 함수
//    refreshSequencePreview
//    → 이전 재로딩 작업 취소
//    → 가장 최신 순서로 재로딩 요청
//
//    rebuildSequencePreview
//    → 새 타임라인 시간표 생성
//    → 새 A → B → C 재생 영상 생성
//    → 기존 선택 클립 위치로 이동
//    → 자동 재생
    private func refreshSequencePreview(
        preferredSelectionID: UUID?
    ) {
        sequenceReloadTask?.cancel()

        sequenceReloadTask = Task { [weak self] in
            guard let self else {
                return
            }

            await self.rebuildSequencePreview(
                preferredSelectionID: preferredSelectionID
            )
        }
    }
    
    private func rebuildSequencePreview(
        preferredSelectionID: UUID?
    ) async {
        editorTimeline = ClipEditorTimeline(
            clips: orderedClips
        )

        do {
            try await loadSequencePreview()

            guard !Task.isCancelled else {
                return
            }

            let selectedID: UUID?

            if
                let preferredSelectionID,
                orderedClips.contains(
                    where: { $0.id == preferredSelectionID }
                )
            {
                selectedID = preferredSelectionID
            } else {
                selectedID = orderedClips.first(
                    where: { $0.mediaType == .video }
                )?.id
            }

            guard let selectedID else {
                stopPreview()

                state = .failed(
                    ErrorPresentation(
                        message: "편집할 영상이 없어요.",
                        recoveryAction: .none
                    )
                )
                return
            }

            selectPreview(
                id: selectedID,
                shouldPlay: true
            )

            state = .content
        } catch {
            guard !Task.isCancelled else {
                return
            }

            state = .failed(
                ClipEditorErrorPolicy.playbackPresentation(
                    for: error
                )
            )
        }
    }

    private func movePlayback(
        to globalTime: TimeInterval
    ) {
        guard editorTimeline.totalDuration > 0 else {
            return
        }

        let safeTime = min(
            max(globalTime, 0),
            editorTimeline.totalDuration
        )

        playbackProgress = safeTime
            / editorTimeline.totalDuration

        updatePlayingPosition(
            for: safeTime
        )

        videoPlaybackService.seek(
            to: safeTime
        )
    }

    private func updatePlayingPosition(
        for globalTime: TimeInterval
    ) {
        guard let segment = editorTimeline.segment(
            at: globalTime
        ) else {
            playingClipID = nil
            playingLocalTime = 0
            return
        }

        playingClipID = segment.clipID

        playingLocalTime = segment.localTime(
            for: globalTime
        )
    }
    
    func retryPrepare() async {
        hasPrepared = false

        selectedPreview = nil
        playbackProgress = 0
        playingClipID = nil
        playingLocalTime = 0

        videoPlaybackService.stop()

        await prepare()
    }
    
    func dismissExportError() {
        exportError = nil
    }
      
        
}
