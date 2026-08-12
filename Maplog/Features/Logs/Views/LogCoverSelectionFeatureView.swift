//
//  LogCoverSelectionFeatureView.swift
//  Maplog
//
//  Created by 한채림 on 8/12/26.
//

import SwiftUI

struct LogCoverSelectionFeatureView: View {
    @StateObject private var viewModel: LogCoverSelectionViewModel // 커버 선택 화면이 떠 있는 동안 viewModel을 소유

    private let onSave: (LogCoverFrame) -> Void // 선택 시간을 로그 작성 화면으로 돌려보냄

    @Environment(\.dismiss) private var dismiss

    init(
            input: LogCoverSelectionInput,
            videoThumbnailService: any VideoThumbnailService,
            onSave: @escaping (LogCoverFrame) -> Void
        ) {
            self.onSave = onSave

            _viewModel = StateObject(
                wrappedValue: LogCoverSelectionViewModel(
                    input: input,
                    videoThumbnailService: videoThumbnailService
                )
            )
        }

    var body: some View {
            LogCoverSelectionView(
                viewModel: viewModel,
                onApply: {
                    guard
                        let selectedFrame = viewModel.selectedFrame,
                        selectedFrame.thumbnailData != nil
                    else {
                        return
                    }

                    onSave(selectedFrame)
                    dismiss()
                }
            )
        }
}
