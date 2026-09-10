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
    @State private var isClipListExpanded = false
    @State private var showsCropEditor = false
    @State private var hasShownLocationTemplateHint = false
    @State private var isLocationTemplateHintVisible = false
    @State private var playbackFeedbackSymbol: String?
    @State private var playbackFeedbackTask: Task<Void, Never>?
    @State private var pendingLogComposeInput: LogComposeInput?
    @State private var logComposeInput: LogComposeInput?

    let previewPlayer: AVPlayer
    let videoPlaybackService: any VideoPlaybackService
    let videoThumbnailService: any VideoThumbnailService
    let logLocationRepository: any LogLocationRepository
    let logPublishingRepository: any LogPublishingRepository
    let photoLibraryVideoSaveService: any PhotoLibraryVideoSaving
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
            playbackFeedbackTask?.cancel()

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
                if let pendingInput = pendingLogComposeInput {
                        pendingLogComposeInput = nil
                        logComposeInput = pendingInput
                        return
                    }

                Task {
                        await viewModel.restoreSelectedPreview()
                    }
            }
        ) { result in
            VideoExportPreviewView(
                result: result,
                player: previewPlayer,
                aspectRatio: viewModel.previewAspectRatio,
                onPreviewAppear: {
                        viewModel.playExportedVideo(result)
                    },
                onWriteLogTap: {
                        guard let input = viewModel.makeLogComposeInput(
                            for: result
                        ) else {
                            return
                        }

                        pendingLogComposeInput = input
                        exportPreviewResult = nil
                    }
            )
        }
        .fullScreenCover(
            item: $logComposeInput,
            onDismiss: {
                Task {
                    await viewModel.restoreSelectedPreview()
                }
            }
        ) { input in
            NavigationStack {
                LogComposeFeatureView(
                    input: input,
                    videoPlaybackService: videoPlaybackService,
                    videoThumbnailService: videoThumbnailService,
                    logLocationRepository: logLocationRepository,
                    logPublishingRepository: logPublishingRepository,
                    photoLibraryVideoSaveService: photoLibraryVideoSaveService
                )
            }
        }
        .sheet(isPresented: $showsCropEditor) {
            ClipEditorCropView(viewModel: viewModel, player: previewPlayer)
        }
        .onChange(of: viewModel.isTextEditing) { _, isEditing in
            if isEditing { isClipListExpanded = false }
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
            VStack(spacing: 0) {
                previewCanvas(
                    height: previewHeight(for: proxy.size)
                )
                .zIndex(1)

                if !viewModel.isTextEditing {
                    editorTimelineControls
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
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
            size.width / viewModel.previewAspectRatio

        let availableHeight =
            size.height
            - ClipEditorLayout.timelineControlsHeight

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
            playbackFeedbackSymbol: playbackFeedbackSymbol,
            onTextOverlayTap: { id in
                isClipListExpanded = false
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

                guard !viewModel.isTextEditing else {
                    return
                }

                togglePreviewPlaybackFromCanvas()
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
            , aspectRatio: viewModel.previewAspectRatio
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
                isMuted: viewModel.isPreviewMuted,
                canUndoTextOverlayEdit: viewModel.canUndoTextOverlayEdit,
                onFinishTextEditing: finishKeyboardEditing,
                onClose: {
                    dismiss()
                },
                onUndoTap: {
                    isLocationTemplateHintVisible = false
                    finishKeyboardEditing()
                    viewModel.undoLastTextOverlayEdit()
                },
                onTextTap: {
                    viewModel.addTextOverlayToCurrentClip()
                },
                onLocationTap: {
                    viewModel.addLocationTimestampOverlayToCurrentClip()
                },
                onMuteTap: {
                    viewModel.togglePreviewMute()
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
        .overlay(alignment: .bottom) {
            if isClipListExpanded && !viewModel.isTextEditing {
                expandedClipList
            }
        }
        .overlay(alignment: .bottom) {
            if !viewModel.isTextEditing {
                ClipEditorPlaybackScrubberView(
                    progress: viewModel.playbackProgress,
                    onSeek: { progress in
                        viewModel.seekPreview(to: progress)
                    }
                )
                .offset(
                    y: ClipEditorLayout.playbackScrubberHeight / 2
                )
            }
        }
    }

    /// 목록은 영상 위로 펼쳐서 미리보기의 크기와 글자 좌표를 유지한다.
    private var editorTimelineControls: some View {
        VStack(spacing: MaplogSpacing.small) {
            HStack(spacing: MaplogSpacing.small) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isClipListExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: MaplogSpacing.xxSmall) {
                        Image(systemName: "rectangle.stack")
                        Text("클립 \(viewModel.timelineItems.count)개")
                        Image(systemName: isClipListExpanded ? "chevron.down" : "chevron.up")
                    }
                    .font(MaplogFont.calloutStrong)
                    .frame(minHeight: MaplogSize.minimumTapTarget)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(isClipListExpanded ? "클립 목록 접기" : "클립 목록 펼치기")

                Spacer(minLength: 0)

                Button(action: togglePreviewPlaybackFromCanvas) {
                    Image(systemName: viewModel.isPreviewPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(viewModel.isPreviewPlaying ? "일시정지" : "재생")
                Text("\(viewModel.currentPlaybackTimeText) / \(viewModel.totalDurationText)")
                    .font(MaplogFont.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(Color.maplogInk)
            .buttonStyle(.plain)

            exportActionButton
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, MaplogSpacing.xSmall)
        .padding(.bottom, MaplogSpacing.medium)
        .frame(height: ClipEditorLayout.timelineControlsHeight)
        .background(Color.maplogSurface)
        .zIndex(2)
    }

    private var expandedClipList: some View {
        VStack(spacing: MaplogSpacing.small) {
            if viewModel.compositionConfiguration.layout != .single {
                Button {
                    showsCropEditor = true
                } label: {
                    Label("분할 영역 조정", systemImage: "crop")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .frame(minHeight: MaplogSize.minimumTapTarget)
                }
                .font(MaplogFont.calloutStrong)
                .foregroundStyle(Color.maplogInk)
            }
            timelineSection
        }
        .padding(MaplogSpacing.small)
        .background(Color.maplogSurface, in: UnevenRoundedRectangle(
            topLeadingRadius: MaplogRadius.xLarge,
            topTrailingRadius: MaplogRadius.xLarge
        ))
    }

    private func finishKeyboardEditing() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    private var timelineSection: some View {
        ClipEditorTimelineStripView(
            items: viewModel.timelineItems,
            selectedID: viewModel.selectedPreview?.id,
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
            HStack(spacing: MaplogSpacing.xxSmall) {
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
                    foreground: .maplogOnPrimary
                ),
                size: .large,
                fullWidth: true
            )
        )
        .disabled(
            viewModel.isExporting
            || viewModel.isUpdatingCrop
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

    private func togglePreviewPlaybackFromCanvas() {
        guard viewModel.totalDuration > 0 else {
            return
        }

        viewModel.togglePreviewPlayback()

        showPlaybackFeedback(
            symbol: viewModel.isPreviewPlaying
            ? "pause.fill"
            : "play.fill"
        )
    }

    private func showPlaybackFeedback(
        symbol: String
    ) {
        playbackFeedbackTask?.cancel()

        withAnimation(.easeOut(duration: 0.14)) {
            playbackFeedbackSymbol = symbol
        }

        playbackFeedbackTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 700_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            withAnimation(.easeOut(duration: 0.18)) {
                playbackFeedbackSymbol = nil
            }
        }
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
