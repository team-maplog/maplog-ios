//
//  CameraCaptureView.swift
//  Maplog
//
//  Created by 한채림 on 7/31/26.
//

import SwiftUI

struct CameraCaptureView: View {
    @ObservedObject var viewModel: CameraCaptureViewModel
    @State private var isCompositionQuickPickerPresented = false
    
    let onClose: () -> Void
    let onLatestClipTap: () -> Void
    
    var body: some View {
        ZStack {
            previewContent

            screenContent

            if isCompositionQuickPickerPresented {
                compositionQuickPicker
                    .transition(
                        .move(edge: .bottom)
                            .combined(with: .opacity)
                    )
            }
        }
        .animation(
            .spring(response: 0.28, dampingFraction: 0.86),
            value: isCompositionQuickPickerPresented
        )
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
        .task {
            await viewModel.prepare()  // 화면 진입 시 viewModel.prepare() 실행
        } // prepare() → 권한 확인 → 세션 구성 → 세션 시작 → .ready
//        CameraPreviewView와 상단 버튼 표시
        .onDisappear { // 닫기 또는 다른 탭으로 이동해 화면이 사라짐 → .onDisappear → stopSession()
            Task {
                await viewModel.stopSession()
            }
        }
        .alert( // 토치·카메라 전환처럼 작은 실패 → 전체 화면을 실패 화면으로 바꾸지 않고 actionError alert만 표시
            "카메라 오류",
            isPresented: Binding(
                get: { viewModel.actionError != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissActionError()
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                viewModel.dismissActionError()
            }
        } message: {
            Text(viewModel.actionError?.message ?? "")
        }
    }

    private var compositionQuickPicker: some View {
        VStack {
            Spacer(minLength: 0)

            CameraCompositionQuickPicker(
                configuration: viewModel.settings.compositionConfiguration,
                onConfigurationChange: { configuration in
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        viewModel.updateCompositionConfiguration(configuration)
                    }
                }
            )
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.bottom, 176)
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        if shouldShowPreview {
            let configuration = viewModel.settings.compositionConfiguration

            if configuration.layout == .single
                && configuration.sceneOrientation == .vertical {
                CameraPreviewView(session: viewModel.previewSession)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    CameraCompositionCapturePreview(
                        session: viewModel.previewSession,
                        configuration: configuration,
                        activeSlotIndex: viewModel.activeCompositionSlotIndex
                    )
                    .frame(
                        width: max(0, proxy.size.width - 40),
                        height: max(360, proxy.size.height - 270)
                    )
                    .position(
                        x: proxy.size.width / 2,
                        y: proxy.size.height / 2 + 18
                    )
                }
                .ignoresSafeArea()
            }
        } else {
            Color.black
                .ignoresSafeArea()
        }
    }
    
        private var shouldShowPreview: Bool {
            switch viewModel.state {
            case .preparing, .ready, .countingDown, .recording, .saving:
                return true
                
            case .idle, .permissionDenied, .failed:
                return false
            }
        }
        
        @ViewBuilder
        private var screenContent: some View {
            switch viewModel.state {
            case .idle, .preparing:
                    loadingView

                case .ready: // 상단 버튼 + 길이 선택 + 라임 셔터
                    readyControls

                case .recording:
                    recordingControls

                case .saving: // 조작 대신 저장 로딩 표시
                    savingView

                case .countingDown: // 시작 타이머 구현 전까지는 기존 상단 버튼만 표시
                    topControls

                case .permissionDenied:
                    permissionDeniedView

                case .failed(let presentation):
                    failedView(presentation)
            }
        }
        
    private var readyControls: some View {
        VStack(spacing: 0) {
            topControls
            compositionProgressHeader

            Spacer()

            ZStack(alignment: .bottomLeading) {
                VStack(spacing: MaplogSpacing.medium) {
                    if viewModel.settings.compositionConfiguration.layout != .single
                        || viewModel.settings.compositionConfiguration.sceneOrientation == .horizontal {
                        Text(
                            "한 칸 \(viewModel.settings.compositionConfiguration.captureFrameRatioTitle) 프레임"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, MaplogSpacing.small)
                        .padding(.vertical, MaplogSpacing.xxSmall)
                        .background(.black.opacity(0.36), in: Capsule())
                    }

                    durationPicker
                    
                    shutterButton
                }
                
                if viewModel.lastSavedDraft != nil {
                    Button(action: onLatestClipTap) {
                        CameraLatestClipThumbnail(thumbnailData: viewModel.latestThumbnailData)
                            .offset(
                                x: -64,
                                y: -16
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("최근 촬영 클립 열기")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, MaplogSpacing.xLarge)
            .padding(.bottom, MaplogSpacing.xxLarge)
        }
    }
    
    private var recordingControls: some View {
        VStack(spacing: 16) {
            topControls
            compositionProgressHeader

            Spacer()

            Text("\(Int((viewModel.recordingProgress * viewModel.settings.clipDuration.seconds).rounded(.down))) / \(Int(viewModel.settings.clipDuration.seconds))s")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()

            shutterButton
                .padding(.bottom, 32)
        }
    }
    
    private var savingView: some View {
        ProgressView("클립을 저장 중이에요")
                .tint(.white)
                .foregroundStyle(.white)
    }
    
    // 길이 선택 UI
    private var durationPicker: some View {
        HStack(spacing: 12) {
            ForEach(CaptureClipDuration.allCases, id: \.rawValue) { duration in
                let isSelected =
                viewModel.settings.clipDuration == duration
                
                Button {
                    viewModel.selectClipDuration(duration)
                } label: {
                    Text(duration.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isSelected ? .black : .white)
                        .frame(minWidth: 48)
                        .padding(.vertical, 10)
                        .background(
                            isSelected ? .white : .black.opacity(0.32),
                            in: Capsule()
                        )
                    
                }
            }
        }
        .disabled(viewModel.isRecording)
    }
    
    // 셔터
    private var shutterButton: some View {
        Button {
            isCompositionQuickPickerPresented = false
            viewModel.shutterTapped()
        } label: {
                ZStack {
                    if viewModel.isRecording {
                        Circle()
                                            .trim(
                                                from: 0,
                                                to: viewModel.recordingProgress
                                            )
                                            .stroke(
                                                                    .red,
                                                                    style: StrokeStyle(
                                                                        lineWidth: 5,
                                                                        lineCap: .round
                                                                    )
                                                                )
                                                                .rotationEffect(.degrees(-90))
                                                                .frame(width: 94, height: 94)
                                                                .animation(
                                                                    .linear(duration: 0.04),
                                                                    value: viewModel.recordingProgress
                                                                )
                    }
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 78, height: 78)
                    
                    if viewModel.isRecording {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(.red)
                                        .frame(width: 44, height: 44)
                                        .animation(
                                            .easeInOut(duration: 0.16),
                                            value: viewModel.isRecording
                                        )
                                } else {
                                    Circle()
                                        .fill(Color.maplogLime)
                                        .frame(width: 62, height: 62)
                                        .animation(
                                            .easeInOut(duration: 0.16),
                                            value: viewModel.isRecording
                                        )
                                }
                }
                .frame(width: 96, height: 96)
               
                   
            }
            .accessibilityLabel(
                viewModel.isRecording ? "녹화 중지" : "영상 촬영 시작"
            )
            .accessibilityValue(
                    viewModel.isRecording
                        ? "\(Int(viewModel.recordingProgress * 100))퍼센트 진행"
                        : ""
                )
    }
    
        private var loadingView: some View {
            ProgressView("카메라를 준비 중이에요")
                .tint(.white)
                .foregroundStyle(.white)
        }
        
    private var topControls: some View {
                HStack {
                    circleButton(
                        icon: "xmark",
                        accessibilityLabel: "카메라 닫기",
                        action: onClose
                    )
                    
                    Spacer()
                    
                    compositionConfigurationButton
                        .opacity(viewModel.isRecording ? 0.4 : 1)
                        .disabled(viewModel.isRecording)

                    circleButton(
                        icon: viewModel.isTorchEnabled
                        ? "bolt.fill"
                        : "bolt.slash.fill",
                        accessibilityLabel: viewModel.isTorchEnabled
                        ? "조명 끄기"
                        : "조명 켜기"
                    ) {
                        Task {
                            await viewModel.toggleTorch()
                        }
                    }
                    .opacity(viewModel.isTorchAvailable ? 1 : 0.35)
                    .disabled(!viewModel.isTorchAvailable)
                    
                    circleButton(
                        icon: "camera.rotate",
                        accessibilityLabel: "전면 후면 카메라 전환"
                    ) {
                        Task {
                            await viewModel.switchCamera()
                        }
                    }
                }
                .padding(.horizontal, MaplogSpacing.xLarge)
                .padding(.top, MaplogSpacing.xSmall)
            
        }

    private var compositionConfigurationButton: some View {
        Button {
            isCompositionQuickPickerPresented.toggle()
        } label: {
            Image("MaplogCollageGlyph")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 21, height: 21)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.28), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("분할 영상 구성 선택")
        .accessibilityValue(
            "(viewModel.settings.compositionConfiguration.sceneOrientation.title), "
                + "(viewModel.settings.compositionConfiguration.layout.title)"
        )
        .accessibilityHint(
            isCompositionQuickPickerPresented
                ? "분할 구성 선택기를 닫습니다"
                : "세로 또는 가로 장면과 분할 수를 바로 선택합니다"
        )
    }

    @ViewBuilder
    private var compositionProgressHeader: some View {
        let configuration = viewModel.settings.compositionConfiguration

        if configuration.layout != .single {
            HStack(spacing: MaplogSpacing.xSmall) {
                Text("\(configuration.requiredClipCount)컷 촬영")
                    .font(MaplogFont.calloutStrong)

                Text("\(viewModel.activeCompositionSlotIndex + 1) / \(configuration.requiredClipCount)")
                    .font(MaplogFont.caption)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.68))

                Spacer(minLength: 0)

                Text("프레임 \(configuration.captureFrameRatioTitle)")
                    .font(MaplogFont.badge)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, MaplogSpacing.xSmall)
                    .padding(.vertical, MaplogSpacing.xxSmall)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, MaplogSpacing.xLarge)
            .padding(.top, MaplogSpacing.xSmall)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(configuration.requiredClipCount)컷 촬영, \(viewModel.activeCompositionSlotIndex + 1)번째 장면"
            )
        }
    }
        
        private var permissionDeniedView: some View {
            VStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 34))
                
                Text("카메라 접근 권한이 필요해요")
                    .font(.headline)
                
                Text("설정에서 카메라 권한을 허용한 뒤 다시 시도해 주세요.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .foregroundStyle(.white)
            .padding(28)
        }
        
        private func failedView(
            _ presentation: ErrorPresentation
        ) -> some View {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                
                Text(presentation.message)
                    .multilineTextAlignment(.center)
                
                if presentation.recoveryAction == .retry {
                    Button("다시 시도") {
                        Task {
                            await viewModel.retry()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .foregroundStyle(.white)
            .padding(28)
        }
        
        private func circleButton(
            icon: String,
            accessibilityLabel: String,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.28), in: Circle())
            }
            .accessibilityLabel(accessibilityLabel)
            
        }
    }
