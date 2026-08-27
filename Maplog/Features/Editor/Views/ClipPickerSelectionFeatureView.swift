//
//  ClipPickerSelectionFeatureView.swift
//  Maplog
//
//  Created by 한채림 on 8/4/26.
// 추가 선택 전용 Feature
//선택 화면 ViewModel 생성·소유
//→ 사용자가 선택 완료
//→ 선택한 실제 클립들을 Editor에 전달
//→ 자기 전체 화면 닫기

import SwiftUI

struct ClipPickerSelectionFeatureView: View {
    @StateObject private var viewModel: ClipPickerViewModel

    private let onComplete: ([CaptureDraftClip]) -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        mediaDraftRepository: any MediaDraftRepository,
        videoThumbnailService: any VideoThumbnailService,
        photoLibraryVideoImportService: any PhotoLibraryVideoImporting,
        initialSelectedClipIDs: [UUID],
        onComplete: @escaping ([CaptureDraftClip]) -> Void
    ) {
        self.onComplete = onComplete

        _viewModel = StateObject(
            wrappedValue: ClipPickerViewModel(
                mediaDraftRepository: mediaDraftRepository,
                videoThumbnailService: videoThumbnailService,
                photoLibraryVideoImportService: photoLibraryVideoImportService,
                initialSelectedClipIDs: initialSelectedClipIDs
            )
        )
    }

    var body: some View {
        ClipPickerView(
            viewModel: viewModel,
            allowsPermanentDeletion: false,
            allowsCompositionSelection: false,
            confirmationTitle: { count in
                "\(count)개 클립 적용하기"
            },
            onConfirmSelection: { clips in
                onComplete(clips)
                dismiss()
            }
        )
    }
}
