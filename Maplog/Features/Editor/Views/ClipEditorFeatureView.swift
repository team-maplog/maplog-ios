//
//  ClipEditorFeatureView.swift
//  Maplog
//
//  Created by 한채림 on 8/2/26.
//

import SwiftUI

struct ClipEditorFeatureView: View {
    @StateObject private var viewModel: ClipEditorViewModel
    @State private var isClipSelectionPresented = false
    
    private let mediaDraftRepository: any MediaDraftRepository
    private let videoThumbnailService: any VideoThumbnailService
    private let videoPlaybackService: any VideoPlaybackService // 재생기를 보관
    
    init(
        input: ClipEditorInput,
        mediaDraftRepository: any MediaDraftRepository,
        videoThumbnailService: any VideoThumbnailService,
        videoPlaybackService: any VideoPlaybackService,
        videoExportService: any VideoExportService
    ) {
        self.mediaDraftRepository = mediaDraftRepository
        self.videoThumbnailService = videoThumbnailService
        self.videoPlaybackService = videoPlaybackService
        _viewModel = StateObject(wrappedValue: ClipEditorViewModel(
            input: input,
            videoThumbnailService: videoThumbnailService,
            videoPlaybackService: videoPlaybackService,
            videoExportService: videoExportService
        )
        )
    }
    
    var body: some View {
        ClipEditorView(
            viewModel: viewModel,
            previewPlayer: videoPlaybackService.player,
            onAddClipTap: {
                isClipSelectionPresented = true
            }
        )
        .fullScreenCover(
            isPresented: $isClipSelectionPresented,
            onDismiss: { // 추가 선택 화면이 열릴 때 Editor의 재생기가 멈출 수 있기 때문에 restoreSelectedPreview()가 새 선택 결과 기준으로 A → B → C 시퀀스를 다시 만들고 자동 재생
                Task {
                    await viewModel.restoreSelectedPreview()
                }
            }
        ) {
            ClipPickerSelectionFeatureView(
                mediaDraftRepository: mediaDraftRepository,
                videoThumbnailService: videoThumbnailService,
                initialSelectedClipIDs: viewModel.editingClipIDsInOrder,
                onComplete: { selectedClips in
                    viewModel.applyClipSelection(selectedClips)
                }
            )
        }
    }
}
