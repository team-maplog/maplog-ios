//
//  ClipEditorView.swift
//  Maplog
//
//  Created by 한채림 on 8/2/26.
//

import AVFoundation
import SwiftUI

struct ClipEditorView: View {
    @ObservedObject var viewModel: ClipEditorViewModel
    @State private var exportPreviewResult: VideoExportResult?
    
    let previewPlayer: AVPlayer
    let onAddClipTap: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group{
                switch viewModel.state {
                case .loading:
                    ProgressView("클립을 준비하고 있어요.")
                    
                case .content:
                    contentView
                    
                case .failed(let presentation):
                    failedView(presentation)
                }
            }
                .padding(MaplogSpacing.page)
                .navigationTitle("클립 편집")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("클립 편집 닫기")
                    }
                }
        }
        .task {
            await viewModel.prepare()
        }
        .onDisappear {
            if exportPreviewResult == nil {
                    viewModel.stopPreview()
                }
        }
        .alert(
            "영상 만들기 실패",
            isPresented: exportErrorBinding
        ) {
            if viewModel.exportError?.recoveryAction == .retry {
                Button("다시 시도") {
                    Task {
                        await viewModel.exportVideo()
                    }
                }
            }

            Button("확인", role: .cancel) {
                viewModel.dismissExportError()
            }
        } message: {
            Text(viewModel.exportError?.message ?? "")
        }
        .onChange(of: viewModel.exportedVideo) { exportedVideo in // export 성공 결과가 생김
            guard let exportedVideo else {
                return
            }

//            ClipEditorView
//            → 결과를 감지
//            → ViewModel에게 재생 준비 요청
//            → 미리보기 화면 표시
//
//            VideoExportPreviewView
//            → 전달받은 AVPlayer를 화면에 표시
//            → 닫기 버튼으로 자기 화면만 닫음
            
            exportPreviewResult = exportedVideo
        }
        .fullScreenCover(
            item: $exportPreviewResult,
            onDismiss: {
                Task {
                        await viewModel.restoreSelectedPreview()
                    }
            }
        ) { result in
            VideoExportPreviewView(
                result: result,
                player: previewPlayer,
                onPreviewAppear: {
                        viewModel.playExportedVideo(result)
                    }
            )
        }
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: MaplogSpacing.section
            ) {
                VStack(
                    alignment: .leading,
                    spacing: MaplogSpacing.xxSmall
                ) {
                    Text("선택한 클립")
                        .font(MaplogFont.screenTitle)
                    
                    Text(
                        "\(viewModel.timelineItems.count)개 클립이 선택 순서대로 준비됐어요."
                    )
                    .font(MaplogFont.callout)
                    .foregroundStyle(.secondary)
                }
                
                previewSection
                
                timelineSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MaplogSpacing.page)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            exportActionButton
        }
    }
    
    private func failedView(
        _ presentation: ErrorPresentation
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("미리보기를 열지 못했어요")
                .font(.title3.weight(.bold))

            Text(presentation.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if presentation.recoveryAction == .retry {
                Button("다시 시도") {
                    Task {
                        await viewModel.retryPrepare()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.maplogLime)
                .foregroundStyle(Color.maplogInk)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var previewSection: some View {
        VStack(
                alignment: .leading,
                spacing: MaplogSpacing.small
            ) {
                Text("미리보기")
                    .font(.headline)

                ClipEditorPreviewView(
                    player: previewPlayer,
                    selectedItem: viewModel.selectedPreview,
                    displayOrder: viewModel.selectedPreview.flatMap { item in
                        viewModel.timelineOrder(for: item.id)
                    },
                    playbackProgress: viewModel.playbackProgress
                )
            }
    }
    
    private var timelineSection: some View {
        VStack(
            alignment: .leading,
            spacing: MaplogSpacing.small
        ) {
            Text("타임라인")
                .font(.headline)
            
            
            ClipEditorTimelineStripView(
                items: viewModel.timelineItems,
                selectedID: viewModel.selectedPreview?.id,
                orderForID: { id in
                    viewModel.timelineOrder(for: id)
                },
                canRemove: viewModel.canRemoveClip,
                onRemove: { id in
                    viewModel.removeClip(id: id)
                },
                
                onSelect: { id in
                    viewModel.selectPreview(id: id)
                },
                onMove: { sourceID, targetID in
                    viewModel.moveClip(
                        id: sourceID,
                        to: targetID
                    )
                },
                onAdd: onAddClipTap
            )
        }
    }
    
    private var exportActionButton: some View {
        Button {
            Task {
                await viewModel.exportVideo()
            }
        } label: {
            HStack(spacing: MaplogSpacing.small) {
                if viewModel.isExporting {
                    ProgressView()
                        .tint(Color.maplogInk)
                } else {
                    Image(systemName: "film")
                }
                
                Text(
                    viewModel.isExporting
                    ? "영상 만드는 중…"
                    : "영상 만들기"
                )
            }
        }
        .buttonStyle(
            MaplogButtonStyle(
                variant: .brand(
                    background: .maplogLime,
                    foreground: .maplogInk
                ),
                size: .large,
                fullWidth: true
            )
        )
        .disabled(
            viewModel.isExporting
            || viewModel.timelineItems.isEmpty
        )
        .accessibilityLabel(
            viewModel.isExporting
            ? "영상 만드는 중"
            : "영상 만들기"
        )
        .accessibilityHint(
            "현재 타임라인 순서대로 클립을 하나의 영상으로 만듭니다."
        )
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.vertical, MaplogSpacing.small)
        .background(.ultraThinMaterial)
    }
    
    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.exportError != nil
            },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissExportError()
                }
            }
        )
    }
}
