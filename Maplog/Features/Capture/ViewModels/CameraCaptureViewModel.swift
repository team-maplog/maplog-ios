//
//  CameraCaptureViewModel.swift
//  Maplog
//
//  Created by 한채림 on 7/31/26.
//

//화면 진입
//→ 카메라 권한 확인
//→ 마이크 권한 확인
//→ 후면 카메라 세션 구성
//→ 세션 시작
//→ state = .ready

import AVFoundation
import Foundation

@MainActor
final class CameraCaptureViewModel: ObservableObject {
    @Published private(set) var state: CameraCaptureState = .idle
    @Published private(set) var currentPosition: CameraPosition
    @Published private(set) var isTorchAvailable = false // 현재 카메라가 토치를 지원하는지
    @Published private(set) var isMicrophoneAuthorized = false
    @Published private(set) var isTorchEnabled = false // 지원한다면, 토치가 지금 켜져 있는지
    @Published private(set) var actionError: ErrorPresentation? // 전환·토치 버튼처럼 작은 행동만 실패했을 때 보여줄 오류, 토치를 못 켰다고 카메라 미리보기 전체를 실패 화면으로 바꿀 필요는 없으니까, state = .failed 대신 actionError만 바꿈
    @Published private(set) var settings = CameraCaptureSettings()
    @Published private(set) var lastSavedDraft: CaptureDraftClip? // 방금 찍은 클립 썸네일과 편집 화면 진입 버튼을 만들 때
    @Published private(set) var recordingProgress: Double = 0
    @Published private(set) var latestThumbnailData: Data? // 최근 저장 영상의 JPEG 파일 내용, 다음 단계에서 View가 이것을 화면 이미지로 바꿔 그림
    @Published private(set) var activeCompositionSlotIndex = 0

    private let mediaDraftRepository: any MediaDraftRepository

    private var automaticStopTask: Task<Void, Never>?
    private var recordingCapturedAt: Date?
    private var recordingTimestampStyle: CaptureTimestampStyle?
    private var recordingLocation: CaptureLocation?  // 녹화 위치 임시 보관값, 촬영 시작 위치 복사본

    let previewSession: AVCaptureSession

    private let cameraCaptureService: any CameraCaptureService
    private let videoThumbnailService: any VideoThumbnailService
    private let captureLocationService: any CaptureLocationService

    init(
        cameraCaptureService: any CameraCaptureService,
        mediaDraftRepository: any MediaDraftRepository,
        videoThumbnailService: any VideoThumbnailService,
        captureLocationService: any CaptureLocationService
    ) {
        self.cameraCaptureService = cameraCaptureService
        self.mediaDraftRepository = mediaDraftRepository
        self.videoThumbnailService = videoThumbnailService
        self.captureLocationService = captureLocationService
        previewSession = cameraCaptureService.previewSession
        currentPosition = cameraCaptureService.currentPosition
    }

    func prepare() async {
        guard state == .idle else {
            return
        }

        state = .preparing

        let cameraStatus = await cameraCaptureService
            .requestCameraAuthorization()

        guard !Task.isCancelled else {
            state = .idle
            return
        }

        guard cameraStatus == .authorized else {
            state = .permissionDenied
            return
        }

        let microphoneStatus = await cameraCaptureService
            .requestMicrophoneAuthorization()

        isMicrophoneAuthorized = microphoneStatus == .authorized

        do {
            try await cameraCaptureService.configureSession(position: .rear)

            guard !Task.isCancelled else {
                state = .idle
                return
            }

            await cameraCaptureService.startSession()

            guard !Task.isCancelled else {
                await cameraCaptureService.stopSession()
                state = .idle
                return
            }

            captureLocationService.startUpdatingLocation() // 처음 카메라에 들어가면 카메라·마이크 권한 다음으로 위치 권한을 요청

            currentPosition = cameraCaptureService.currentPosition

            isTorchAvailable = await cameraCaptureService
                .isTorchAvailable()

            state = .ready // 권한 확인, 후면 카메라 구성, 세션 시작, 조명 가능 여부 확인까지 모두 성공했으니 이제 촬영 버튼을 눌러도 됨

            Task { [weak self] in // 화면 진입 시 최근 클립 불러오기, 카메라 프리뷰가 먼저 즉시 뜨고, 썸네일은 뒤에서 준비
                await self?.loadLatestDraft()
            }
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(CameraCaptureErrorPolicy.presentation(for: error))
        }
    }

    func retry() async {
        guard case .failed = state else {
            return
        }

        state = .idle

        await prepare()
    }

    // 전면/후면 전환 함수
//    View의 전환 버튼 탭
//    → ViewModel.switchCamera()
//    → Service가 실제 카메라 입력을 앞/뒤로 교체
//    → Service가 결과 위치 반환
//    → ViewModel.currentPosition 갱신
//    → View는 아이콘·상태를 다시 그림
    func switchCamera() async {
        guard case .ready = state else {
            return
        }

        actionError = nil

        do {
            currentPosition = try await cameraCaptureService
                .switchCamera()

            isTorchAvailable = await cameraCaptureService
                .isTorchAvailable()

            isTorchEnabled = false
        } catch {
            actionError = CameraCaptureErrorPolicy.presentation(for: error)
        }
    }

    // 토치 토글 함수
    func toggleTorch() async {
        guard case .ready = state, isTorchAvailable else {
            return
        }

        actionError = nil

        let nextTorchEnabled = !isTorchEnabled // nextTorchEnabled는 현재 값의 반대
//        현재 false → 버튼 탭 → true → 조명 켜기
//        현재 true  → 버튼 탭 → false → 조명 끄기
        do {
            try await cameraCaptureService.setTorchEnabled(nextTorchEnabled)

            isTorchEnabled = nextTorchEnabled
        } catch {
            actionError = CameraCaptureErrorPolicy.presentation(for: error)
        }
    }

    func dismissActionError() {
        actionError = nil
    }

    // 길이 선택과 셔터 행동
    var isRecording: Bool {
        guard case .recording = state else {
            return false
        }

        return true
    }

    func selectClipDuration(_ duration: CaptureClipDuration) {
        guard case .ready = state else {
            return
        }

        settings.clipDuration = duration
    }

    func updateCompositionConfiguration(
        _ configuration: VideoCompositionConfiguration
    ) {
        settings.compositionConfiguration = configuration
        activeCompositionSlotIndex = 0
    }

    func shutterTapped() {
        switch state {
        case .ready:
            Task {
                await startRecording()
            }

        case .recording:
            Task {
                await finishRecording()
            }

        default:
            return
        }
    }

    // 실제 녹화용 함수
//    2초 선택
//    → 녹화 시작
//    → state = .recording
//    → 2초 대기
//    → finishRecording()
//    → 카메라 녹화 종료
//    → 임시 .mov 받기
//    → Repository가 초안 폴더에 저장
    private func startRecording() async {
        guard case .ready = state else {
            return
        }

        actionError = nil

        let capturedAt = Date()
        let capturedLocation = captureLocationService.latestLocation
        let selectedDuration = settings.clipDuration.seconds
        let timestampStyle = settings.timestampStyle

        do {
            try await cameraCaptureService.startRecording()

            recordingCapturedAt = capturedAt
            recordingTimestampStyle = timestampStyle
            recordingLocation = capturedLocation
            recordingProgress = 0
            state = .recording

            scheduleAutomaticStop(after: selectedDuration) // 선택한 영상 길이만큼 시간이 지나면 finishRecording()을 실행
        } catch {
            actionError = CameraCaptureErrorPolicy.presentation(for: error)
        }
    }

    private func scheduleAutomaticStop(after duration: TimeInterval) {
        automaticStopTask?.cancel()

        automaticStopTask = Task { @MainActor [weak self] in
            let recordingStartedAt = Date()

            while !Task.isCancelled {
                guard let self else {
                    return
                }

                let elapsed = Date().timeIntervalSince(recordingStartedAt) // 녹화가 시작된 뒤 지금까지 몇 초가 지났는지

                recordingProgress = min(elapsed / duration, 1)

                if recordingProgress >= 1 {
                    await finishRecording()
                    return
                }

                do {
                    try await Task.sleep(
                        nanoseconds: 33_333_333
                    )
                } catch {
                    return
                }
            }
        }
    }

    private func finishRecording() async {
        guard case .recording = state else {
             return
        }

        automaticStopTask?.cancel()
        automaticStopTask = nil

        state = .saving

        let capturedAt = recordingCapturedAt ?? Date()
        let timestampStyle = recordingTimestampStyle ?? settings.timestampStyle
        let location = recordingLocation

        defer {
            recordingCapturedAt = nil
            recordingTimestampStyle = nil
            recordingLocation = nil
            recordingProgress = 0
        }

        do {
            let recordedVideo = try await cameraCaptureService.stopRecording()

            let input = CaptureDraftClipInput(
                temporaryFileURL: recordedVideo.temporaryFileURL,
                mediaType: .video,
                capturedAt: capturedAt,
                duration: recordedVideo.duration,
                location: location,
                timestampStyle: timestampStyle)

            // 새 영상이 저장되면 그 파일에서 첫 프레임을 바로 뽑아 latestThumbnailData에 담음
            let savedDraft = try await mediaDraftRepository.saveDraft(from: input)

            lastSavedDraft = savedDraft
            latestThumbnailData = nil
            moveToNextCompositionSlot()

            await loadThumbnail(for: savedDraft)

            state = .ready
        } catch {
            state = .ready
            actionError = CameraCaptureErrorPolicy.presentation(for: error)
        }
    }

    /// 분할 촬영은 한 번에 화면을 합성하는 방식이 아니라, 각 칸에 들어갈 클립을
    /// 차례로 촬영합니다. 초안 저장이 성공한 경우에만 다음 칸으로 이동합니다.
    private func moveToNextCompositionSlot() {
        let configuration = settings.compositionConfiguration

        guard configuration.layout != .single else {
            activeCompositionSlotIndex = 0
            return
        }

        activeCompositionSlotIndex =
            (activeCompositionSlotIndex + 1) % configuration.requiredClipCount
    }

    // 최근 초안 조회 + 썸네일 생성
    private func loadLatestDraft() async {
        do {
            let drafts = try await mediaDraftRepository.fetchDrafts()

            guard !Task.isCancelled else {
                return
            }

            guard let latestDraft = drafts.first else {
                lastSavedDraft = nil
                latestThumbnailData = nil
                return
            }

            lastSavedDraft = latestDraft
            latestThumbnailData = nil

            await loadThumbnail(for: latestDraft)
        } catch {
            // 썸네일·최근 클립 조회 실패는
                    // 카메라 촬영 자체를 막지 않으므로 조용히 기본 UI를 유지한다.
        }
    }

    private func loadThumbnail(for draft: CaptureDraftClip) async {
        guard draft.mediaType == .video else {
            latestThumbnailData = nil
            return
        }

        let thumbnailData = try? await videoThumbnailService
            .makeThumbnailData(for: draft.fileURL)

        guard
            !Task.isCancelled,
            lastSavedDraft?.id == draft.id // 영상이 최신 영상일 때만 썸네일을 반영
//                A 영상 썸네일 생성 중
//                → 사용자가 B 영상을 새로 촬영
//                → B가 최신 영상이 됨
//                → 늦게 끝난 A의 썸네일이 B 썸네일 자리를 덮으면 안 됨
        else {
            return
        }
        latestThumbnailData = thumbnailData
    }

    func stopSession() async {
        automaticStopTask?.cancel()
        automaticStopTask = nil
        recordingCapturedAt = nil
        recordingTimestampStyle = nil
        recordingLocation = nil
        recordingProgress = 0

        captureLocationService.stopUpdatingLocation()
        await cameraCaptureService.stopSession()

        isTorchAvailable = false
        isTorchEnabled = false
        state = .idle
    }
}
