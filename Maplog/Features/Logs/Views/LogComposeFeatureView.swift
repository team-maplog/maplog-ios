//
//  LogComposeFeatureView.swift
//  Maplog
//
//  Created by 한채림 on 8/9/26.
//

import SwiftUI

struct LogComposeFeatureView: View {
    @StateObject private var viewModel: LogComposeViewModel
    @State private var selectedClipLocation: LogComposeClipLocationDraft?
    @State private var coverSelectionInput: LogCoverSelectionInput?

    private let videoPlaybackService: any VideoPlaybackService
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
        self.videoPlaybackService = videoPlaybackService
        self.videoThumbnailService = videoThumbnailService
        self.logLocationRepository = logLocationRepository
        self.logPublishingRepository = logPublishingRepository
        self.photoLibraryVideoSaveService = photoLibraryVideoSaveService

        _viewModel = StateObject(
            wrappedValue: LogComposeViewModel(
                input: input,
                videoPlaybackService: videoPlaybackService,
                videoThumbnailService: videoThumbnailService,
                logLocationRepository: logLocationRepository,
                logPublishingRepository: logPublishingRepository,
                photoLibraryVideoSaveService: photoLibraryVideoSaveService
            )
        )
    }

    var body: some View {
        LogComposeView(
                viewModel: viewModel,
                previewPlayer: videoPlaybackService.player,
                onCoverChangeTap: {
                    viewModel.pausePreview() // 커버를 고르는 동안 뒤 화면 재생만 멈춥니다.

                    coverSelectionInput = viewModel.makeCoverSelectionInput()
                },
                onClipLocationTap: { clipID in
                    selectedClipLocation = viewModel.clipLocation(
                        for: clipID
                    )
                }
            )
            .task {
                await viewModel.prepare()
            }
            .onDisappear {
                // navigationDestination 전환에도 호출될 수 있으므로 재생 항목은 유지합니다.
                viewModel.pausePreview()
            }
            .navigationDestination(
                item: $selectedClipLocation
            ) { clipLocation in
                ClipLocationEditFeatureView(
                    logLocationRepository: logLocationRepository,
                    clipLocation: clipLocation,
                    thumbnailData: viewModel.thumbnailData(
                        for: clipLocation.id
                    ),
                    onSave: { updatedClipLocation in
                        viewModel.updateClipLocation(
                            updatedClipLocation
                        )
                    }
                )
            }
            .navigationDestination(
                item: $coverSelectionInput
            ) { input in
                LogCoverSelectionFeatureView(
                    input: input,
                    videoThumbnailService: videoThumbnailService,
                    onSave: { selectedFrame in
                        viewModel.selectCover(selectedFrame)
                    }
                )
            }
    }
}
