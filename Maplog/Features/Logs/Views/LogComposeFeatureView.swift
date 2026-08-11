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
    private let videoPlaybackService: any VideoPlaybackService
    private let logLocationRepository: any LogLocationRepository

    init(
        input: LogComposeInput,
        videoPlaybackService: any VideoPlaybackService,
        videoThumbnailService: any VideoThumbnailService,
        logLocationRepository: any LogLocationRepository
    ) {
        self.videoPlaybackService = videoPlaybackService
        self.logLocationRepository = logLocationRepository

        _viewModel = StateObject(
            wrappedValue: LogComposeViewModel(
                input: input,
                videoPlaybackService: videoPlaybackService,
                videoThumbnailService: videoThumbnailService
            )
        )
    }

    var body: some View {
        LogComposeView(
                viewModel: viewModel,
                previewPlayer: videoPlaybackService.player,
                onCoverChangeTap: {

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
    }
}
