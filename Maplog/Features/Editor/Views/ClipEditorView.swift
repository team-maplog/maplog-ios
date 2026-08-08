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
    @State private var isOverlayDragging = false
    @State private var hasShownLocationTemplateHint = false
    @State private var isLocationTemplateHintVisible = false
    @State private var isEditorPanelExpanded = false // 하단 패널 상태

    let previewPlayer: AVPlayer
    let onAddClipTap: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
                Color.black
                    .ignoresSafeArea()

                switch viewModel.state {
                case .loading:
                    ProgressView("클립을 준비하고 있어요.")
                        .tint(.white)
                        .foregroundStyle(.white)

                case .content:
                    contentView

                case .failed(let presentation):
                    failedView(presentation)
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
        .onChange(
            of: viewModel.selectedLocationTimestampTemplate
        ) { template in
            guard
                template != nil,
                !hasShownLocationTemplateHint
            else {
                return
            }

            hasShownLocationTemplateHint = true
            isLocationTemplateHintVisible = true
        }
    }

    private var contentView: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                previewCanvas(
                    height: previewHeight(for: proxy.size)
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )

                if !viewModel.isTextEditing {
                    editorBottomPanel
                        .zIndex(1)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
        .background(Color.maplogSurface)
        .ignoresSafeArea(edges: .top)
    }
    
    private func previewHeight(
        for size: CGSize
    ) -> CGFloat {
        if viewModel.isTextEditing {
            return size.height
        }

        let videoHeightForFullWidth =
            size.width * (16.0 / 9.0)

        let availableHeight =
            size.height
            - ClipEditorLayout.playbackControlsHeight
            - ClipEditorLayout.collapsedEditorPanelHeight

        return min(
            videoHeightForFullWidth,
            max(0, availableHeight)
        )
    }

    private func previewCanvas(
        height: CGFloat
    ) -> some View {
        ClipEditorPreviewView(
            player: previewPlayer,
            selectedItem: viewModel.selectedPreview,
            textOverlayItems: viewModel.visibleTextOverlayItems,
            selectedTextOverlayID: viewModel.selectedTextOverlayID,
            onTextOverlayTap: { id in
                isLocationTemplateHintVisible = false
                viewModel.selectTextOverlay(id: id)
            },
            onTextOverlayPositionChange: { id, position in
                viewModel.updateTextOverlayPosition(
                    id: id,
                    position: position
                )
            },
            onOverlayDraggingChanged: { isDragging in
                guard isOverlayDragging != isDragging else {
                    return
                }
                isOverlayDragging = isDragging // 화면에서 도구들을 숨길지 결정하는 로컬 상태
                viewModel.setOverlayDragging(isDragging) // 재생 진행률 갱신을 잠시 막고, 드래그 시작 때 영상을 멈추는 상태 처리
            },

            onTextOverlayDelete: { id in
                viewModel.deleteTextOverlay(id: id)
            },
            textInputRequestID: viewModel.textInputRequestID,
            onTextInputRequestHandled: { id in // 나중에 UIKit이 키보드 열기 완료했어라고 알려줄 때, ViewModel의 요청을 지워 주는 통로
                viewModel.finishTextInputRequest(for: id)
            },
            onTextOverlayTextChange: { id, text in
                viewModel.updateTextOverlayText(
                    id: id,
                    text: text
                )
            },
            onTextOverlayTextEditingFinished: { id in
                viewModel.finishTextEditing(id: id) // 빈 텍스트면 삭제하고, 아니면 앞뒤 공백 정리
                viewModel.endTextEditing(id: id) // 지금 입력 중 상태를 끝냄
            },
            onPreviewBackgroundTap: {
                isLocationTemplateHintVisible = false
                viewModel.selectTextOverlay(id: nil)
            },
            onTextOverlayTextEditingStarted: { id in
                viewModel.beginTextEditing(id: id)
            },
            onTemplateSwipe: { offset in
                isLocationTemplateHintVisible = false

                viewModel.moveSelectedLocationTimestampTemplate(
                    by: offset
                )
            },
            showsAlignmentGrid: isOverlayDragging
        )
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Color.black)
        .overlay(alignment: .bottom) {
            if
                viewModel.activeTool == .text,
                let item = viewModel.selectedTextOverlayItem
            {
                ClipEditorTextStylePanel(
                    item: item,
                    onFontSizeChange: { amount in
                        viewModel.changeSelectedTextFontSize(
                            by: amount
                        )
                    },
                    onFontSelect: { font in
                        viewModel.updateSelectedTextFont(font)
                    },
                    onWeightSelect: { weight in
                        viewModel.updateSelectedTextWeight(weight)
                    },
                    onColorSelect: { color in
                        viewModel.updateSelectedTextColor(color)
                    }
                )
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.bottom, MaplogSpacing.xxSmall)
                .opacity(isOverlayDragging ? 0 : 1)
                .allowsHitTesting(!isOverlayDragging)
                .animation(nil, value: isOverlayDragging)
            }
        }

        .overlay(alignment: .top) {
            ClipEditorTopControlsView(
                activeTool: viewModel.activeTool,
                isTextEditing: viewModel.isTextEditing,
                onClose: {
                    dismiss()
                },
                onTextTap: {
                    viewModel.addTextOverlayToCurrentClip()
                },
                onLocationTap: {
                    viewModel.addLocationTimestampOverlayToCurrentClip()
                },
                onStickerTap: {
                    viewModel.toggleActiveTool(.sticker)
                }
            )
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.top, ClipEditorLayout.topControlsTopInset)
            .opacity(isOverlayDragging ? 0 : 1)
            .allowsHitTesting(!isOverlayDragging)
            .animation(nil, value: isOverlayDragging)
        }
        .overlay(alignment: .bottom) { // 편집 화면을 연 동안 한 번만 표시되고, 다른 곳을 탭하거나 실제 스와이프를 하면 사라짐
            if isLocationTemplateHintVisible {
                Text("좌우로 밀어 위치·시간 스타일 변경")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, MaplogSpacing.small)
                    .padding(.vertical, MaplogSpacing.xxSmall)
                    .background(
                        .ultraThinMaterial,
                        in: Capsule()
                    )
                    .padding(.bottom, MaplogSpacing.medium)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .clipped()
    }

    // ViewModel의 상태를 화면용 컴포넌트에 전달하고, 버튼·슬라이더에서 발생한 행동은 다시 ViewModel에 전달하는 연결부
//    사용자 재생 버튼 탭
//    → ClipEditorPlaybackControlsView의 onPlayPauseTap 실행
//    → viewModel.togglePreviewPlayback() 실행
//    → ViewModel이 PlaybackService에 재생 또는 일시정지 요청
//    → isPreviewPlaying 값 변경
//    → SwiftUI가 버튼 아이콘을 다시 그림
    private var playbackControls: some View {
        ClipEditorPlaybackControlsView(
                isPlaying: viewModel.isPreviewPlaying,
                isMuted: viewModel.isPreviewMuted,
                currentTimeText: viewModel.currentPlaybackTimeText,
                totalTimeText: viewModel.totalDurationText,
                progress: viewModel.playbackProgress,
                onPlayPauseTap: {
                    viewModel.togglePreviewPlayback()
                },
                onMuteTap: {
                    viewModel.togglePreviewMute()
                },
                onSeek: { progress in
                    viewModel.seekPreview(to: progress)
                }
            )    }

    private var editorBottomPanel: some View {
        VStack(spacing: 0) {
            playbackControls

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditorPanelExpanded.toggle()
                }
            } label: {
                VStack(spacing: 4) {
                    Capsule()
                        .fill(Color.maplogInk.opacity(0.24))
                        .frame(width: 36, height: 4)

                    HStack {
                        Text(
                            "클립 편집 · \(viewModel.timelineItems.count)개"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.maplogInk)

                        Spacer()

                        Image(
                            systemName: isEditorPanelExpanded
                            ? "chevron.down"
                            : "chevron.up"
                        )
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.maplogInk)
                    }
                }
                .padding(.horizontal, MaplogSpacing.page)
                .frame(
                    height: ClipEditorLayout.collapsedEditorPanelHeight
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("클립 편집 패널")
            .accessibilityValue(
                isEditorPanelExpanded ? "펼쳐짐" : "접힘"
            )

            if isEditorPanelExpanded {
                VStack(spacing: MaplogSpacing.small) {
                    timelineSection
                    exportActionButton
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, MaplogSpacing.xxSmall)
                .padding(.bottom, MaplogSpacing.small)
                .transition(
                    .move(edge: .bottom)
                        .combined(with: .opacity)
                )
            }
        }
        .background(Color.maplogSurface)
        .shadow(
            color: .black.opacity(0.12),
            radius: 12,
            y: -4
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: isEditorPanelExpanded
        )
    }

    private var timelineSection: some View {
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
            ? "완성 중"
            : "완성하기"
        )
        .accessibilityHint(
            "현재 타임라인 순서대로 클립을 하나의 영상으로 만듭니다."
        )
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
