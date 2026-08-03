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
    
    init(
        mediaDraftRepository: any MediaDraftRepository,
        videoThumbnailService: any VideoThumbnailService,
        videoPlaybackService: any VideoPlaybackService,
        videoExportService: any VideoExportService
        
    ) {
        self.mediaDraftRepository = mediaDraftRepository
        self.videoThumbnailService = videoThumbnailService
        self.videoPlaybackService = videoPlaybackService
        self.videoExportService = videoExportService
        _viewModel = StateObject(
            wrappedValue: ClipPickerViewModel(
                mediaDraftRepository: mediaDraftRepository,
                videoThumbnailService: videoThumbnailService
            )
        )
    }
    
    var body: some View {
        ClipPickerView(
            viewModel: viewModel,
            allowsPermanentDeletion: true,
            confirmationTitle: { count in
                "\(count)개 클립 편집하기"
            },
            onConfirmSelection: { clips in
                editorInput = ClipEditorInput(
                    clips: clips
                )
            }
        )
        .fullScreenCover(item: $editorInput) { input in
            ClipEditorFeatureView(
                input: input,
                mediaDraftRepository: mediaDraftRepository,
                videoThumbnailService: videoThumbnailService,
                videoPlaybackService: videoPlaybackService,
                videoExportService: videoExportService
            )
        }
    }
}
