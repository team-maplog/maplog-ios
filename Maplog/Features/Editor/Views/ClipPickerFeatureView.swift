//
//  ClipPickerFeatureView.swift
//  Maplog
//
//  Created by 한채림 on 8/1/26.
//

import SwiftUI


struct ClipPickerFeatureView: View {
    @StateObject private var viewModel: ClipPickerViewModel
    @State private var editorInput: ClipEditorInput? // 편집 화면 전환을 소유

    private let mediaDraftRepository: any MediaDraftRepository
    private let videoThumbnailService: any VideoThumbnailService
    private let videoPlaybackService: any VideoPlaybackService
    private let videoExportService: any VideoExportService
    private let logLocationRepository: any LogLocationRepository
    private let logPublishingRepository: any LogPublishingRepository
    private let photoLibraryVideoImportService: any PhotoLibraryVideoImporting
    private let photoLibraryVideoSaveService: any PhotoLibraryVideoSaving
    private let onCompositionConfigurationChanged: (VideoCompositionConfiguration) -> Void

    init(
        mediaDraftRepository: any MediaDraftRepository,
        videoThumbnailService: any VideoThumbnailService,
        videoPlaybackService: any VideoPlaybackService,
        videoExportService: any VideoExportService,
        logLocationRepository: any LogLocationRepository,
        logPublishingRepository: any LogPublishingRepository,
        photoLibraryVideoImportService: any PhotoLibraryVideoImporting,
        photoLibraryVideoSaveService: any PhotoLibraryVideoSaving,
        initialCompositionConfiguration: VideoCompositionConfiguration = .init(),
        onCompositionConfigurationChanged: @escaping (VideoCompositionConfiguration) -> Void = { _ in }

    ) {
        self.mediaDraftRepository = mediaDraftRepository
        self.videoThumbnailService = videoThumbnailService
        self.videoPlaybackService = videoPlaybackService
        self.videoExportService = videoExportService
        self.logLocationRepository = logLocationRepository
        self.logPublishingRepository = logPublishingRepository
        self.photoLibraryVideoImportService = photoLibraryVideoImportService
        self.photoLibraryVideoSaveService = photoLibraryVideoSaveService
        self.onCompositionConfigurationChanged = onCompositionConfigurationChanged
        _viewModel = StateObject(
            wrappedValue: ClipPickerViewModel(
                mediaDraftRepository: mediaDraftRepository,
                videoThumbnailService: videoThumbnailService,
                photoLibraryVideoImportService: photoLibraryVideoImportService,
                initialCompositionConfiguration: initialCompositionConfiguration
            )
        )
    }

    var body: some View {
        ClipPickerView(
            viewModel: viewModel,
            allowsPermanentDeletion: true,
            allowsCompositionSelection: true,
            confirmationTitle: { count in
                "\(count)개 클립 편집하기"
            },
            onConfirmSelection: { clips in
                editorInput = ClipEditorInput(
                    clips: clips,
                    compositionConfiguration: viewModel.compositionConfiguration
                )
            }
        )
        .onChange(of: viewModel.compositionConfiguration) { _, configuration in
            onCompositionConfigurationChanged(configuration)
        }
        .fullScreenCover(item: $editorInput) { input in
            ClipEditorFeatureView(
                input: input,
                mediaDraftRepository: mediaDraftRepository,
                videoThumbnailService: videoThumbnailService,
                videoPlaybackService: videoPlaybackService,
                videoExportService: videoExportService,
                logLocationRepository: logLocationRepository,
                logPublishingRepository: logPublishingRepository,
                photoLibraryVideoImportService: photoLibraryVideoImportService,
                photoLibraryVideoSaveService: photoLibraryVideoSaveService
            )
        }
    }
}
