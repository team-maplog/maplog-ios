//
//  ClipLocationEditFeatureView.swift
//  Maplog
//
//  Created by 한채림 on 8/10/26.
//

import SwiftUI

struct ClipLocationEditFeatureView: View {
    @StateObject private var viewModel: ClipLocationEditViewModel

    private let thumbnailData: Data?
    private let onSave: (LogComposeClipLocationDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        logLocationRepository: any LogLocationRepository,
        clipLocation: LogComposeClipLocationDraft,
        thumbnailData: Data?,
        onSave: @escaping (LogComposeClipLocationDraft) -> Void
    ) {
        self.thumbnailData = thumbnailData
        self.onSave = onSave

        _viewModel = StateObject(
            wrappedValue: ClipLocationEditViewModel(
                clipLocation: clipLocation,
                logLocationRepository: logLocationRepository
            )
        )
    }

    var body: some View {
        ClipLocationEditView(
            viewModel: viewModel,
            thumbnailData: thumbnailData,
            onSave: {
                onSave(viewModel.makeUpdatedClipLocation())
                dismiss()
            }
        )
    }
}
