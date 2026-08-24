import AVFoundation
import Foundation

enum LogDetailScreenState: Equatable {
    case idle
    case initialLoading
    case content
    case failed(ErrorPresentation)
}

@MainActor
final class LogDetailViewModel: ObservableObject {
    @Published private(set) var state: LogDetailScreenState = .idle
    @Published private(set) var detail: LogDetail?
    @Published private(set) var thumbnailData: Data?
    @Published private(set) var clipThumbnailDataByID: [Int64: Data] = [:]
    @Published private(set) var loadingClipThumbnailIDs = Set<Int64>()
    @Published private(set) var isLoadingPlayback = false
    @Published private(set) var playbackErrorMessage: String?
    @Published private(set) var playbackProgress = 0.0
    @Published private(set) var isPlaying = false
    @Published var captionDraft = ""
    @Published private(set) var isSavingCaption = false
    @Published private(set) var captionFormMessage: String?
    @Published private(set) var captionMessage: String?
    @Published private(set) var captionRecoveryAction: ErrorPresentation.RecoveryAction?
    @Published private(set) var isDeleting = false
    @Published private(set) var deletionError: ErrorPresentation?
    @Published private(set) var shouldRemoveFromSourceList = false

    let player: AVPlayer

    private let logID: Int64
    private let logDetailRepository: any LogDetailRepository
    private let logMediaRepository: any LogMediaRepository
    private let playbackService: any VideoPlaybackService

    init(
        logID: Int64,
        logDetailRepository: any LogDetailRepository,
        logMediaRepository: any LogMediaRepository,
        playbackService: any VideoPlaybackService
    ) {
        self.logID = logID
        self.logDetailRepository = logDetailRepository
        self.logMediaRepository = logMediaRepository
        self.playbackService = playbackService
        self.player = playbackService.player
    }

    func loadIfNeeded() async {
        guard state == .idle else {
            return
        }

        await reload()
    }

    func reload() async {
        guard state != .initialLoading else {
            return
        }

        state = .initialLoading
        detail = nil
        thumbnailData = nil
        clipThumbnailDataByID = [:]
        loadingClipThumbnailIDs = []
        playbackErrorMessage = nil
        playbackProgress = 0
        isPlaying = false
        shouldRemoveFromSourceList = false
        clearCaptionMessages()
        deletionError = nil
        playbackService.stop()

        do {
            let detail = try await logDetailRepository.fetchDetail(logID: logID)

            guard !Task.isCancelled else {
                return
            }

            self.detail = detail
            captionDraft = detail.caption
            state = .content

            await loadPlayback()
            await loadThumbnail()
            await loadClipThumbnails(for: detail.clips)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else {
                return
            }

            shouldRemoveFromSourceList = LogDetailErrorPolicy
                .shouldRemoveFromSourceList(for: error)
            state = .failed(
                LogDetailErrorPolicy.detailPresentation(for: error)
            )
        }
    }

    func retryInitialLoad() async {
        guard case .failed = state else {
            return
        }

        state = .idle
        await loadIfNeeded()
    }

    func loadPlayback() async {
        guard detail != nil,
              !isLoadingPlayback
        else {
            return
        }

        isLoadingPlayback = true
        playbackErrorMessage = nil
        playbackProgress = 0
        isPlaying = false

        defer {
            isLoadingPlayback = false
        }

        do {
            let fileURL = try await logMediaRepository.fetchPlaybackFileURL(
                logID: logID
            )

            guard !Task.isCancelled else {
                return
            }

            playbackService.loadVideo(at: fileURL)
            playbackService.observeProgress { [weak self] progress in
                self?.playbackProgress = progress
            }
            // AVPlayerLooper는 "반복"만 담당합니다. 실제 재생 시작은 별도로
            // 요청해야 하므로, 상세 진입 직후에도 영상이 자동으로 재생됩니다.
            playbackService.play()
            isPlaying = true
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else {
                return
            }

            playbackErrorMessage = "영상을 불러오지 못했어요. 다시 시도해 주세요."
            isPlaying = false
        }
    }

    func beginCaptionEditing() {
        captionDraft = detail?.caption ?? ""
        clearCaptionMessages()
    }

    func updateCaptionDraft(
        _ caption: String
    ) {
        captionDraft = caption
        clearCaptionMessages()
    }

    func cancelCaptionEditing() {
        captionDraft = detail?.caption ?? ""
        clearCaptionMessages()
    }

    func saveCaption() async -> Bool {
        guard !isSavingCaption,
              let detail
        else {
            return false
        }

        clearCaptionMessages()

        let trimmedCaption = captionDraft.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedCaption.isEmpty else {
            captionMessage = "캡션을 입력해 주세요."
            return false
        }

        guard trimmedCaption.count <= 1_000 else {
            captionMessage = "캡션은 1,000자 이하로 입력해 주세요."
            return false
        }

        isSavingCaption = true
        defer {
            isSavingCaption = false
        }

        do {
            let result = try await logDetailRepository.updateCaption(
                logID: detail.id,
                caption: trimmedCaption
            )

            guard !Task.isCancelled else {
                return false
            }

            self.detail = detail.replacingCaption(with: result.caption)
            captionDraft = result.caption
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard !Task.isCancelled else {
                return false
            }

            apply(
                LogDetailErrorPolicy.captionPresentation(for: error)
            )
            return false
        }
    }

    func deleteLog() async -> Bool {
        guard !isDeleting else {
            return false
        }

        isDeleting = true
        deletionError = nil

        defer {
            isDeleting = false
        }

        do {
            try await logDetailRepository.deleteLog(logID: logID)
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard !Task.isCancelled else {
                return false
            }

            if LogDetailErrorPolicy.shouldRemoveFromSourceList(for: error) {
                return true
            }

            deletionError = LogDetailErrorPolicy.deletionPresentation(for: error)
            return false
        }
    }

    func dismissDeletionError() {
        deletionError = nil
    }

    func stopPlayback() {
        playbackService.stop()
        playbackProgress = 0
        isPlaying = false
    }

    func pausePlayback() {
        playbackService.pause()
        isPlaying = false
    }

    func resumePlayback() {
        guard !isLoadingPlayback,
              playbackErrorMessage == nil,
              detail != nil
        else {
            return
        }

        playbackService.play()
        isPlaying = true
    }

    func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            resumePlayback()
        }
    }

    func seekPlayback(
        to progress: Double
    ) {
        guard let duration = player.currentItem?.duration.seconds,
              duration.isFinite,
              duration > 0
        else {
            return
        }

        let safeProgress = min(max(progress, 0), 1)
        playbackService.seek(to: duration * safeProgress)
        playbackProgress = safeProgress
    }

    private func loadThumbnail() async {
        do {
            let thumbnailData = try await logMediaRepository.fetchThumbnailData(
                logID: logID
            )

            guard !Task.isCancelled else {
                return
            }

            self.thumbnailData = thumbnailData
        } catch is CancellationError {
            return
        } catch {
            // 썸네일은 수정 화면의 미리보기 보조 정보입니다.
            // 실패해도 상세 영상과 캡션 수정 기능은 계속 사용할 수 있어야 합니다.
            thumbnailData = nil
        }
    }

    private func loadClipThumbnails(
        for clips: [LogReelClip]
    ) async {
        for clip in clips {
            guard !Task.isCancelled else {
                return
            }

            await loadClipThumbnail(for: clip)
        }
    }

    private func loadClipThumbnail(
        for clip: LogReelClip
    ) async {
        guard let thumbnailURL = clip.thumbnailURL,
              clipThumbnailDataByID[clip.id] == nil,
              !loadingClipThumbnailIDs.contains(clip.id)
        else {
            return
        }

        loadingClipThumbnailIDs.insert(clip.id)

        defer {
            loadingClipThumbnailIDs.remove(clip.id)
        }

        do {
            let data = try await logMediaRepository
                .fetchRoutePointThumbnailData(from: thumbnailURL)

            guard !Task.isCancelled,
                  detail?.clips.contains(where: { $0.id == clip.id }) == true
            else {
                return
            }

            clipThumbnailDataByID[clip.id] = data
        } catch is CancellationError {
            return
        } catch {
            // 장소 썸네일 한 장의 실패는 상세 화면 전체를 실패시키지 않습니다.
        }
    }

    private func clearCaptionMessages() {
        captionFormMessage = nil
        captionMessage = nil
        captionRecoveryAction = nil
    }

    private func apply(
        _ presentation: LogCaptionEditErrorPresentation
    ) {
        captionFormMessage = presentation.formMessage
        captionMessage = presentation.captionMessage
        captionRecoveryAction = presentation.recoveryAction
    }
}
