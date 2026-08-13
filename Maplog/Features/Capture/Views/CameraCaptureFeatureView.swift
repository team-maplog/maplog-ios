//
//  CameraCaptureFeatureView.swift
//  Maplog
//
//  Created by 한채림 on 7/31/26.
//

import SwiftUI

struct CameraCaptureFeatureView: View {
    @StateObject private var viewModel: CameraCaptureViewModel // CameraCaptureViewModel을 처음 만들고, 카메라 화면이 유지되는 동안 계속 소유
    @State private var isClipPickerPresented = false

    private let mediaDraftRepository: any MediaDraftRepository
    private let videoThumbnailService: any VideoThumbnailService
    private let videoPlaybackService: any VideoPlaybackService
    private let videoExportService: any VideoExportService
    private let logLocationRepository: any LogLocationRepository
    private let logPublishingRepository: any LogPublishingRepository

    let onClose: () -> Void

    init(
        cameraCaptureService: any CameraCaptureService,
        mediaDraftRepository: any MediaDraftRepository,
        videoThumbnailService: any VideoThumbnailService,
        videoPlaybackService: any VideoPlaybackService,
        videoExportService: any VideoExportService,
        captureLocationService: any CaptureLocationService,
        logLocationRepository: any LogLocationRepository,
        logPublishingRepository: any LogPublishingRepository,
        onClose: @escaping () -> Void
    ) {
        self.mediaDraftRepository = mediaDraftRepository
        self.videoThumbnailService = videoThumbnailService
        self.videoPlaybackService = videoPlaybackService
        self.videoExportService = videoExportService
        self.logLocationRepository = logLocationRepository
        self.logPublishingRepository = logPublishingRepository
        _viewModel = StateObject(
            wrappedValue: CameraCaptureViewModel(
                cameraCaptureService: cameraCaptureService,
                mediaDraftRepository: mediaDraftRepository,
                videoThumbnailService: videoThumbnailService,
                captureLocationService: captureLocationService
            )
        )
        self.onClose = onClose
    }

//    최근 썸네일 탭
//    → 카메라 세션 중지
//    → ClipPickerFeatureView 전체 화면 표시
//    → X로 닫기
//    → 카메라 세션 다시 준비·시작
    var body: some View {
        CameraCaptureView(
            viewModel: viewModel, // 이미 만들어진 ViewModel을 전달받기만 함
            onClose: onClose,
            onLatestClipTap: {
                Task { @MainActor in
                    await viewModel.stopSession()
                    isClipPickerPresented = true
                }
            }
        )
        .fullScreenCover(
            isPresented: $isClipPickerPresented,
            onDismiss: {
                Task {
                    await viewModel.prepare()
                }
            }
        ) {
            ClipPickerFeatureView(
                mediaDraftRepository: mediaDraftRepository,
                videoThumbnailService: videoThumbnailService,
                videoPlaybackService: videoPlaybackService,
                videoExportService: videoExportService,
                logLocationRepository: logLocationRepository,
                logPublishingRepository: logPublishingRepository
            )
        }
    }
}
