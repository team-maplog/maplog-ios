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

    init(
        input: LogComposeInput,
        videoPlaybackService: any VideoPlaybackService,
        videoThumbnailService: any VideoThumbnailService,
        logLocationRepository: any LogLocationRepository,
        logPublishingRepository: any LogPublishingRepository
    ) {
        self.videoPlaybackService = videoPlaybackService
        self.videoThumbnailService = videoThumbnailService
        self.logLocationRepository = logLocationRepository
        self.logPublishingRepository = logPublishingRepository

        _viewModel = StateObject(
            wrappedValue: LogComposeViewModel(
                input: input,
                videoPlaybackService: videoPlaybackService,
                videoThumbnailService: videoThumbnailService,
                logPublishingRepository: logPublishingRepository
            )
        )
    }

    var body: some View {
        LogComposeView(
                viewModel: viewModel,
                previewPlayer: videoPlaybackService.player,
                onCoverChangeTap: {
                    viewModel.stopPreview() // 커버를 고르는 동안 뒤 화면의 재생 상태가 남지 않게 하기 위해

                    coverSelectionInput = viewModel.makeCoverSelectionInput()
                },
                onClipLocationTap: { clipID in
                    selectedClipLocation = viewModel.clipLocation(
                        for: clipID
                    )
                },
                onPublishTap: {
                    Task {
                        await viewModel.publish()
                    }
                }
            )
            .task {
                await viewModel.prepare()
            }
            .onDisappear {
                viewModel.stopPreview()
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
