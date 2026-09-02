import AVKit
import SwiftUI

/// 로그 작성이 끝난 뒤, 발행·저장·공유를 각각 독립적으로 실행하는 화면입니다.
/// 여러 목적지를 동시에 고르게 하지 않아 사용자가 실행 결과를 예측할 수 있게 합니다.
struct LogPublicationOptionsView: View {
    @ObservedObject var viewModel: LogComposeViewModel

    let previewPlayer: AVPlayer
    let onMaplogPublished: () -> Void

    @State private var lastAttemptedAction: PublicationAction?
    @State private var completionTask: Task<Void, Never>?

    private enum PublicationAction {
        case maplog
        case photoLibrary
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MaplogSpacing.section) {
                videoPreview
                introduction
                quickActions
                maplogPublicationCard
            }
            .maplogPagePadding()
            .padding(.top, MaplogSpacing.pageTop)
            .padding(.bottom, MaplogSpacing.xxxLarge)
        }
        .navigationTitle("발행 옵션")
        .navigationBarTitleDisplayMode(.inline)
        .maplogScreenSurface()
        .maplogNavigationAppearance()
        .overlay(alignment: .bottom) {
            if let completion = viewModel.publicationCompletion {
                MaplogToast(message: completion.message)
                    .padding(.horizontal, MaplogSpacing.page)
                    .padding(.bottom, MaplogSpacing.xxLarge)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.publicationCompletion)
        .onAppear {
            viewModel.pausePreview()
        }
        .onDisappear {
            completionTask?.cancel()
            viewModel.pausePreview()
        }
        .onChange(of: viewModel.publicationCompletion) { _, completion in
            scheduleCompletionHandling(for: completion)
        }
        .alert(
            "작업을 완료하지 못했어요",
            isPresented: Binding(
                get: { viewModel.publishError != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissPublishError()
                    }
                }
            )
        ) {
            if viewModel.publishError?.recoveryAction == .retry,
               let lastAttemptedAction
            {
                Button("다시 시도") {
                    perform(lastAttemptedAction)
                }
            }

            Button("확인", role: .cancel) {
                viewModel.dismissPublishError()
            }
        } message: {
            Text(viewModel.publishError?.message ?? "")
        }
    }

    private var videoPreview: some View {
        ZStack {
            VideoPlayer(player: previewPlayer)
                .allowsHitTesting(false)

            Button {
                viewModel.togglePreviewPlayback()
            } label: {
                Image(
                    systemName: viewModel.isPreviewPlaying
                    ? "pause.fill"
                    : "play.fill"
                )
                .font(.system(size: MaplogSize.iconMedium, weight: .bold))
                .foregroundStyle(Color.maplogOnPrimary)
                .frame(
                    width: MaplogSize.minimumTapTarget,
                    height: MaplogSize.minimumTapTarget
                )
                .background(Color.maplogPrimary, in: Circle())
            }
            .buttonStyle(MaplogPressFeedbackStyle())
            .accessibilityLabel(
                viewModel.isPreviewPlaying
                ? "영상 일시정지"
                : "영상 재생"
            )
        }
        .frame(height: 188)
        .clipShape(
            RoundedRectangle(
                cornerRadius: MaplogRadius.xLarge,
                style: .continuous
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("완성된 로그 영상 미리보기")
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            Text("로그를 남겨요")
                .font(MaplogFont.screenTitle)
                .foregroundStyle(Color.maplogTextPrimary)

            Text("원하는 방법을 바로 선택할 수 있어요.")
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogTextSecondary)
        }
    }

    private var quickActions: some View {
        VStack(spacing: 0) {
            outputActionRow(
                title: "기기에 저장",
                systemImage: "arrow.down.to.line",
                accessibilityLabel: "완성 영상을 기기에 저장"
            ) {
                perform(.photoLibrary)
            }

            Divider()
                .padding(.horizontal, MaplogSpacing.medium)

            ShareLink(
                item: viewModel.video.fileURL,
                preview: SharePreview("Maplog 로그")
            ) {
                outputActionLabel(
                    title: "공유하기",
                    systemImage: "square.and.arrow.up",
                    isLoading: false
                )
            }
            .disabled(viewModel.isPerformingPublicationAction)
            .accessibilityLabel("완성 영상을 다른 앱으로 공유")
        }
        .maplogCard()
    }

    private var maplogPublicationCard: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("Maplog에 발행")
                .font(MaplogFont.cardTitle)
                .foregroundStyle(Color.maplogTextPrimary)

            Text("내 지도와 피드에 기록해요")
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogTextSecondary)

            if let blockMessage = viewModel.maplogPublicationBlockMessage {
                Text(blockMessage)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogDanger)
                    .accessibilityAddTraits(.isStaticText)
            }

            if viewModel.canRetryLocationResolution {
                Button("위치 다시 조회") {
                    Task {
                        await viewModel.retryLocationResolution()
                    }
                }
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogPrimary)
            }

            PrimaryActionButton(
                viewModel.isPublishingToMaplog
                ? "영상 정리 및 로그 공개 중..."
                : "Maplog에 발행하기",
                isEnabled: viewModel.canPublishToMaplog
            ) {
                perform(.maplog)
            }
        }
        .padding(MaplogSpacing.medium)
        .maplogCard()
    }

    private func outputActionRow(
        title: String,
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            outputActionLabel(
                title: title,
                systemImage: systemImage,
                isLoading: viewModel.isPerformingPublicationAction
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isPerformingPublicationAction)
        .accessibilityLabel(accessibilityLabel)
    }

    private func outputActionLabel(
        title: String,
        systemImage: String,
        isLoading: Bool
    ) -> some View {
        HStack {
            Text(title)
                .font(MaplogFont.bodyStrong)
                .foregroundStyle(Color.maplogTextPrimary)

            Spacer(minLength: MaplogSpacing.small)

            Group {
                if isLoading {
                    ProgressView()
                        .tint(Color.maplogPrimary)
                } else {
                    Image(systemName: systemImage)
                        .font(
                            .system(
                                size: MaplogSize.iconMedium,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(Color.maplogInk)
                }
            }
            .frame(
                width: MaplogSize.minimumTapTarget,
                height: MaplogSize.minimumTapTarget
            )
            .contentShape(Rectangle())
        }
        .padding(.horizontal, MaplogSpacing.medium)
        .frame(minHeight: MaplogSize.controlHeight)
        .contentShape(Rectangle())
    }

    private func perform(
        _ action: PublicationAction
    ) {
        lastAttemptedAction = action

        Task {
            switch action {
            case .maplog:
                await viewModel.publishToMaplog()
            case .photoLibrary:
                await viewModel.saveToPhotoLibrary()
            }
        }
    }

    private func scheduleCompletionHandling(
        for completion: LogPublicationCompletion?
    ) {
        completionTask?.cancel()

        guard let completion else {
            return
        }

        completionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)

            guard !Task.isCancelled else {
                return
            }

            let shouldMoveHome = completion.publishedLog != nil
            viewModel.dismissPublicationCompletion()

            if shouldMoveHome {
                onMaplogPublished()
            }
        }
    }
}
