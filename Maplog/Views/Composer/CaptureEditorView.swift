import SwiftUI

struct CaptureEditorClip: Identifiable, Hashable {
    let id: UUID
    let style: PhotoStyle
    let durationLabel: String
    let isImported: Bool
}

struct CaptureEditorView: View {
    let clips: [CaptureEditorClip]
    let onApply: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var selectedClipID: UUID
    @State private var selectedTool: CaptureEditorTool = .trim
    @State private var playbackPosition = 0.18
    @State private var trimLength = 1.0
    @State private var captionText = ""
    @State private var isMuted = false
    @State private var adjustment = 0.5
    @State private var isPreviewPlaying = false

    init(
        clips: [CaptureEditorClip],
        initialClipID: UUID,
        onApply: @escaping () -> Void
    ) {
        self.clips = clips
        self.onApply = onApply
        _selectedClipID = State(initialValue: initialClipID)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let selectedClip {
                VStack(spacing: 0) {
                    editorHeader
                    preview(for: selectedClip)
                    editControls
                    clipTimeline
                    finishButton
                }
            } else {
                ContentUnavailableView(
                    "편집할 클립이 없어요",
                    systemImage: "film.stack",
                    description: Text("촬영하거나 갤러리에서 클립을 추가해 주세요.")
                )
                .foregroundStyle(.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
        .onChange(of: selectedClipID) { _, _ in
            playbackPosition = 0.18
            trimLength = 1.0
            isPreviewPlaying = false
        }
        .onChange(of: trimLength) { _, newLength in
            playbackPosition = min(playbackPosition, newLength)
        }
    }

    private var selectedClip: CaptureEditorClip? {
        clips.first { $0.id == selectedClipID }
    }

    private var editorHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("촬영으로 돌아가기")

            Spacer()

            Text("클립 편집")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Menu {
                Button("원본 길이로 되돌리기") {
                    trimLength = 1
                    captionText = ""
                    adjustment = 0.5
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("더보기")
        }
        .padding(.horizontal, MaplogSpacing.medium)
        .padding(.top, 6)
        .frame(height: 58)
    }

    private func preview(for clip: CaptureEditorClip) -> some View {
        VStack(spacing: 10) {
            ZStack {
                CaptureTravelImageView(style: clip.style, cornerRadius: 24)
                    .frame(maxWidth: .infinity)
                    .frame(height: 328)
                    .overlay {
                        LinearGradient(
                            colors: [.black.opacity(0.22), .clear, .black.opacity(0.46)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                        isPreviewPlaying.toggle()
                    }
                } label: {
                    Image(systemName: isPreviewPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.52), radius: 8, y: 3)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPreviewPlaying ? "미리보기 일시 정지" : "미리보기 재생")

                HStack {
                    Label(clip.durationLabel, systemImage: "video.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(MaplogSpacing.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }

            HStack(spacing: MaplogSpacing.small) {
                Text(timecode(for: playbackPosition))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                Slider(value: $playbackPosition, in: 0...trimLength)
                    .tint(Color.maplogCaptureAccent)
                    .accessibilityLabel("미리보기 재생 위치")
                Text(timecode(for: trimLength))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, MaplogSpacing.xSmall)
    }

    private var editControls: some View {
        VStack(spacing: MaplogSpacing.small) {
            editorToolPanel

            HStack(spacing: 0) {
                ForEach(CaptureEditorTool.allCases) { tool in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                            selectedTool = tool
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: tool.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                            Text(tool.title)
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(selectedTool == tool ? Color.maplogCaptureAccent : .white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: MaplogSize.minimumTapTarget)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(selectedTool == tool ? Color.maplogCaptureAccent : .clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tool.title)
                    .accessibilityAddTraits(selectedTool == tool ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, MaplogSpacing.medium)
    }

    @ViewBuilder
    private var editorToolPanel: some View {
        switch selectedTool {
        case .trim:
            editorPanel(
                title: "클립 길이",
                detail: String(Int((trimLength * 100).rounded())) + "%"
            ) {
                Slider(value: $trimLength, in: 0.2...1)
                    .tint(Color.maplogCaptureAccent)
                    .accessibilityLabel("클립 길이")
            }
        case .caption:
            editorPanel(title: "자막", detail: captionText.isEmpty ? "없음" : "적용 중") {
                TextField("자막 추가", text: $captionText)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, MaplogSpacing.small)
                    .frame(height: 40)
                    .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
                    .textInputAutocapitalization(.sentences)
            }
        case .sound:
            editorPanel(title: "사운드", detail: isMuted ? "음소거" : "원본 사운드") {
                Toggle(isOn: $isMuted) {
                    Text(isMuted ? "음소거" : "원본 사운드")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .tint(Color.maplogCaptureAccent)
            }
        case .adjust:
            editorPanel(
                title: "밝기",
                detail: String(Int(((adjustment - 0.5) * 100).rounded()))
            ) {
                Slider(value: $adjustment, in: 0...1)
                    .tint(Color.maplogCaptureAccent)
                    .accessibilityLabel("밝기")
            }
        }
    }

    private func editorPanel<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
            }
            content()
        }
        .padding(MaplogSpacing.medium)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
    }

    private var clipTimeline: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            HStack {
                Text("클립 순서")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("클립을 탭해 편집")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MaplogSpacing.small) {
                    ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                        timelineThumbnail(clip, index: index)
                    }
                }
                .padding(.vertical, 3)
            }
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, MaplogSpacing.medium)
    }

    private func timelineThumbnail(_ clip: CaptureEditorClip, index: Int) -> some View {
        let isSelected = selectedClipID == clip.id

        return Button {
            selectedClipID = clip.id
        } label: {
            CaptureTravelImageView(style: clip.style, cornerRadius: MaplogRadius.small)
                .frame(width: 72, height: 92)
                .overlay {
                    RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous)
                        .stroke(
                            isSelected ? Color.maplogCaptureAccent : .white.opacity(0.28),
                            lineWidth: isSelected ? 3 : 1
                        )
                }
                .overlay(alignment: .bottomLeading) {
                    Text("0" + String(index + 1))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(6)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(index + 1) + "번째 " + clip.durationLabel + " 클립")
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
    }

    private var finishButton: some View {
        Button {
            onApply()
            dismiss()
        } label: {
            Text("편집 완료")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.maplogCaptureAccent, in: RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
        }
        .buttonStyle(MaplogPressFeedbackStyle())
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, MaplogSpacing.medium)
        .padding(.bottom, MaplogSpacing.small)
    }

    private func timecode(for progress: Double) -> String {
        let seconds = max(progress, 0) * 2
        return String(format: "0:%.1f", seconds)
    }
}

private enum CaptureEditorTool: CaseIterable, Identifiable, Equatable {
    case trim
    case caption
    case sound
    case adjust

    var id: Self { self }

    var title: String {
        switch self {
        case .trim: return "길이"
        case .caption: return "자막"
        case .sound: return "사운드"
        case .adjust: return "보정"
        }
    }

    var systemImage: String {
        switch self {
        case .trim: return "scissors"
        case .caption: return "textformat"
        case .sound: return "speaker.wave.2"
        case .adjust: return "slider.horizontal.3"
        }
    }
}
