import SwiftUI
import AVFoundation
import UIKit

private enum CaptureToolSheet: Identifiable {
    case timer
    case transition
    case textSticker
    case gallery

    var id: String {
        switch self {
        case .timer:
            return "timer"
        case .transition:
            return "transition"
        case .textSticker:
            return "text-sticker"
        case .gallery:
            return "gallery"
        }
    }
}

private struct RecordedMaplogClip: Identifiable, Hashable {
    let id = UUID()
    let url: URL?
    let style: PhotoStyle
    let durationLabel: String
    let transition: String
    let isImported: Bool
}

private struct PendingMaplogClip {
    let style: PhotoStyle
    let durationLabel: String
    let transition: String
}

private final class CameraRecordingController: NSObject, ObservableObject {
    enum CameraState: Equatable {
        case checking
        case ready
        case denied
        case unavailable(String)
    }

    let session = AVCaptureSession()

    @Published private(set) var state: CameraState = .checking
    @Published private(set) var isRunning = false
    @Published private(set) var isRecording = false
    @Published private(set) var recordedClips: [RecordedMaplogClip] = []
    @Published private(set) var isFrontCamera = false

    private let sessionQueue = DispatchQueue(label: "maplog.camera.session")
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var currentVideoDevice: AVCaptureDevice?
    private var pendingClip: PendingMaplogClip?
    private var stopWorkItem: DispatchWorkItem?

    func start() {
        #if targetEnvironment(simulator)
        state = .unavailable("시뮬레이터에는 실제 카메라 장치가 없어 녹화 동작을 시뮬레이션합니다.")
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestAudioAndConfigure(position: isFrontCamera ? .front : .back)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.requestAudioAndConfigure(position: self.isFrontCamera ? .front : .back)
                } else {
                    DispatchQueue.main.async {
                        self.state = .denied
                    }
                }
            }
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .denied
        }
        #endif
    }

    func stopSession() {
        stopWorkItem?.cancel()
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
                self.isRecording = false
            }
        }
    }

    func recordClip(duration: TimeInterval, durationLabel: String, transition: String, style: PhotoStyle) {
        guard case .ready = state else {
            simulateClip(duration: duration, durationLabel: durationLabel, transition: transition, style: style)
            return
        }

        if isRecording {
            stopRecording()
            return
        }

        pendingClip = PendingMaplogClip(style: style, durationLabel: durationLabel, transition: transition)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("maplog-clip-\(UUID().uuidString).mov")

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.movieOutput.connection(with: .video) != nil else {
                DispatchQueue.main.async {
                    self.simulateClip(duration: duration, durationLabel: durationLabel, transition: transition, style: style)
                }
                return
            }

            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            self.movieOutput.startRecording(to: outputURL, recordingDelegate: self)
            DispatchQueue.main.async {
                self.isRecording = true
            }

            let stopWorkItem = DispatchWorkItem { [weak self] in
                self?.stopRecording()
            }
            self.stopWorkItem = stopWorkItem
            self.sessionQueue.asyncAfter(deadline: .now() + duration, execute: stopWorkItem)
        }
    }

    func stopRecording() {
        stopWorkItem?.cancel()
        stopWorkItem = nil
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            } else {
                DispatchQueue.main.async {
                    self.isRecording = false
                }
            }
        }
    }

    func addImportedClip(style: PhotoStyle, durationLabel: String, transition: String) {
        let clip = RecordedMaplogClip(
            url: nil,
            style: style,
            durationLabel: durationLabel,
            transition: transition,
            isImported: true
        )
        recordedClips.append(clip)
    }

    func switchCamera() {
        guard !isRecording else { return }
        isFrontCamera.toggle()
        #if !targetEnvironment(simulator)
        configureSession(position: isFrontCamera ? .front : .back)
        #endif
    }

    func setTorch(isOn: Bool) {
        guard let currentVideoDevice, currentVideoDevice.hasTorch else { return }
        do {
            try currentVideoDevice.lockForConfiguration()
            currentVideoDevice.torchMode = isOn ? .on : .off
            currentVideoDevice.unlockForConfiguration()
        } catch {
            return
        }
    }

    private func requestAudioAndConfigure(position: AVCaptureDevice.Position) {
        let configure: () -> Void = { [weak self] in
            self?.configureSession(position: position)
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized, .denied, .restricted:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                configure()
            }
        @unknown default:
            configure()
        }
    }

    private func configureSession(position: AVCaptureDevice.Position) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            if let videoInput = self.videoInput {
                self.session.removeInput(videoInput)
            }
            if let audioInput = self.audioInput {
                self.session.removeInput(audioInput)
            }

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoInput)
            else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.state = .unavailable("사용 가능한 카메라를 찾지 못했어요.")
                    self.isRunning = false
                    self.isRecording = false
                }
                return
            }

            self.session.addInput(videoInput)
            self.videoInput = videoInput
            self.currentVideoDevice = videoDevice

            if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
               let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               self.session.canAddInput(audioInput) {
                self.session.addInput(audioInput)
                self.audioInput = audioInput
            }

            if !self.session.outputs.contains(where: { $0 === self.movieOutput }), self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
            }

            self.session.commitConfiguration()
            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.state = .ready
                self.isRunning = self.session.isRunning
                self.isFrontCamera = position == .front
            }
        }
    }

    private func simulateClip(duration: TimeInterval, durationLabel: String, transition: String, style: PhotoStyle) {
        isRecording = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            self.recordedClips.append(
                RecordedMaplogClip(
                    url: nil,
                    style: style,
                    durationLabel: durationLabel,
                    transition: transition,
                    isImported: false
                )
            )
            self.isRecording = false
        }
    }
}

extension CameraRecordingController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        let clip = pendingClip
        pendingClip = nil

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isRecording = false
            guard error == nil, let clip else { return }
            self.recordedClips.append(
                RecordedMaplogClip(
                    url: outputFileURL,
                    style: clip.style,
                    durationLabel: clip.durationLabel,
                    transition: clip.transition,
                    isImported: false
                )
            )
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

private struct CameraFallbackPreview: View {
    let message: String
    var showsProgress = false

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 10) {
                if showsProgress {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.large)
                } else {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, MaplogSpacing.page)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CaptureView: View {
    let initialPlaceName: String?
    var onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraRecordingController()

    @State private var selectedDuration = "1s"
    @State private var selectedTimer = "끄기"
    @State private var selectedTransition = "컷"
    @State private var stickerText = ""
    @State private var activeToolSheet: CaptureToolSheet?
    @State private var isFlashOff = true
    @State private var isGridOn = false
    @State private var toastText: String?
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var showsPlaceMatching = false
    @State private var recordingStartedAt: Date?
    @State private var activeRecordingDuration: TimeInterval = 1
    @State private var selectedEditorClip: CaptureEditorClip?

    private let durations = [".5s", "1s", "2s"]
    private let nextClipStyles: [PhotoStyle] = [.cafe, .city, .palace, .alley, .festival]

    private var capturedStyles: [PhotoStyle] {
        camera.recordedClips.map(\.style)
    }

    private var editorClips: [CaptureEditorClip] {
        camera.recordedClips.map {
            CaptureEditorClip(
                id: $0.id,
                style: $0.style,
                durationLabel: $0.durationLabel,
                isImported: $0.isImported
            )
        }
    }

    private var selectedDurationSeconds: TimeInterval {
        switch selectedDuration {
        case ".5s": return 0.5
        case "2s": return 2.0
        default: return 1.0
        }
    }

    private var selectedTimerSeconds: Int {
        switch selectedTimer {
        case "3초": return 3
        case "5초": return 5
        case "10초": return 10
        default: return 0
        }
    }

    private var nextClipStyle: PhotoStyle {
        nextClipStyles[camera.recordedClips.count % nextClipStyles.count]
    }

    init(initialPlaceName: String? = nil, onClose: (() -> Void)? = nil) {
        let trimmedPlaceName = initialPlaceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.initialPlaceName = trimmedPlaceName?.isEmpty == false ? trimmedPlaceName : nil
        self.onClose = onClose
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                cameraSurface
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()

                if isGridOn {
                    CaptureGridOverlay()
                        .transition(.opacity)
                }

                if !stickerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CaptureTextSticker(text: stickerText)
                        .padding(.top, 130)
                        .transition(.scale.combined(with: .opacity))
                }

                if let countdown {
                    Text("\(countdown)")
                        .font(.system(size: 72, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
                        .transition(.scale.combined(with: .opacity))
                }

                VStack(spacing: 0) {
                    captureTopBar
                    Spacer()
                    toolsAndClips
                    durationPicker
                    shutterRow
                    nextButton
                }

                if let toastText {
                    Text(toastText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 18)
                        .frame(height: 48)
                        .background(Color.maplogSurface)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                        .padding(.bottom, 164)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color.black)
            .clipped()
        }
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
        .onAppear {
            camera.start()
        }
        .onDisappear {
            countdownTask?.cancel()
            camera.stopSession()
        }
        .onChange(of: isFlashOff) { _, newValue in
            camera.setTorch(isOn: !newValue)
        }
        .onChange(of: camera.recordedClips.count) { _, newValue in
            guard newValue > 0 else { return }
            showToast("\(newValue)번째 클립을 저장했어요")
        }
        .onChange(of: camera.isRecording) { _, isRecording in
            if isRecording {
                activeRecordingDuration = selectedDurationSeconds
                recordingStartedAt = .now
            } else {
                recordingStartedAt = nil
            }
        }
        .navigationDestination(item: $selectedEditorClip) { selectedClip in
            CaptureEditorView(
                clips: editorClips,
                initialClipID: selectedClip.id
            ) {
                showToast("클립 편집을 적용했어요")
            }
        }
        .sheet(item: $activeToolSheet) { sheet in
            switch sheet {
            case .timer:
                CaptureTimerSheet(selectedTimer: selectedTimer) { timer in
                    selectedTimer = timer
                    activeToolSheet = nil
                    showToast(timer == "끄기" ? "타이머를 껐어요" : "\(timer) 타이머가 적용됐어요")
                }
                .presentationDetents([.height(324)])
                .presentationDragIndicator(.visible)
            case .transition:
                CaptureTransitionSheet(selectedTransition: selectedTransition) { transition in
                    selectedTransition = transition
                    activeToolSheet = nil
                    showToast("\(transition) 전환 효과를 적용했어요")
                }
                .presentationDetents([.height(334)])
                .presentationDragIndicator(.visible)
            case .textSticker:
                CaptureTextStickerSheet(currentText: stickerText) { text in
                    stickerText = text
                    activeToolSheet = nil
                    showToast(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "텍스트 스티커를 지웠어요" : "텍스트 스티커를 추가했어요")
                }
                .presentationDetents([.height(356)])
                .presentationDragIndicator(.visible)
            case .gallery:
                CaptureGallerySheet(styles: nextClipStyles + [.night, .ocean]) { style in
                    importGalleryClip(style)
                    activeToolSheet = nil
                }
                .presentationDetents([.height(370)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private var cameraSurface: some View {
        ZStack {
            switch camera.state {
            case .ready:
                CameraPreview(session: camera.session)
            case .checking:
                CameraFallbackPreview(message: "카메라를 준비하는 중입니다.", showsProgress: true)
            case .denied:
                CameraFallbackPreview(message: "설정에서 카메라 권한을 허용하면 실제 영상 촬영을 시작할 수 있어요.")
            case .unavailable(let message):
                CameraFallbackPreview(message: message)
            }

            LinearGradient(
                colors: [.black.opacity(0.10), .clear, .black.opacity(0.70)],
                startPoint: .top,
                endPoint: .bottom
            )

            if camera.isRecording {
                VStack {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, MaplogSpacing.small)
                    .frame(height: 30)
                    .background(.black.opacity(0.42))
                    .clipShape(Capsule())
                    .padding(.top, 112)
                    Spacer()
                }
            }
        }
    }

    private var captureTopBar: some View {
        HStack {
            CameraCircleButton(systemImage: "xmark") {
                if let onClose {
                    onClose()
                } else {
                    dismiss()
                }
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "slider.vertical.3")
                Text("Maplog")
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 42)
            .background(.black.opacity(0.42))
            .clipShape(Capsule())
            Spacer()
            HStack(spacing: MaplogSpacing.small) {
                CameraCircleButton(systemImage: isFlashOff ? "bolt.slash.fill" : "bolt.fill") {
                    isFlashOff.toggle()
                    showToast(isFlashOff ? "플래시를 껐어요" : "플래시를 켰어요")
                }
                CameraCircleButton(systemImage: "camera.rotate.fill") {
                    camera.switchCamera()
                    showToast(camera.isFrontCamera ? "전면 카메라 모드" : "후면 카메라 모드")
                }
            }
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, 50)
    }

    private var toolsAndClips: some View {
        HStack(alignment: .bottom, spacing: MaplogSpacing.small) {
            clipStrip
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

            VStack(spacing: MaplogSpacing.medium) {
                CameraCircleButton(systemImage: "clock.arrow.circlepath", isSelected: selectedTimer != "끄기") {
                    activeToolSheet = .timer
                }
                CameraCircleButton(systemImage: "goforward.plus", isSelected: selectedTransition != "컷") {
                    activeToolSheet = .transition
                }
                CameraCircleButton(systemImage: "textformat", isSelected: !stickerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    activeToolSheet = .textSticker
                }
                CameraCircleButton(systemImage: "square.grid.2x2.fill", isSelected: isGridOn) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isGridOn.toggle()
                    }
                    showToast(isGridOn ? "격자 가이드를 켰어요" : "격자 가이드를 껐어요")
                }
            }
        }
        .padding(.horizontal, MaplogSpacing.page)
    }

    private var clipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(Array(camera.recordedClips.enumerated()), id: \.element.id) { index, clip in
                    Button {
                        selectedEditorClip = CaptureEditorClip(
                            id: clip.id,
                            style: clip.style,
                            durationLabel: clip.durationLabel,
                            isImported: clip.isImported
                        )
                    } label: {
                        CaptureTravelImageView(style: clip.style, cornerRadius: MaplogRadius.medium)
                            .frame(width: 68, height: 88)
                            .overlay {
                                RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                                    .stroke(Color.maplogCaptureAccent, lineWidth: 2)
                            }
                            .overlay(alignment: .topTrailing) {
                                Text("\(index + 1)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.maplogInk)
                                    .frame(width: 22, height: 22)
                                    .background(Color.maplogCaptureAccent)
                                    .clipShape(Circle())
                                    .padding(5)
                            }
                            .overlay(alignment: .bottomLeading) {
                                Text(clip.durationLabel)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .frame(minHeight: 22)
                                    .background(.black.opacity(0.56), in: Capsule())
                                    .padding(6)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(index + 1)번째 \(clip.durationLabel) 클립")
                    .accessibilityHint("탭하면 클립 편집 화면을 엽니다.")
                }

                Button {
                    activeToolSheet = .gallery
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                            .fill(.black.opacity(0.22))
                            .overlay {
                                RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                                    .stroke(.white.opacity(0.78), style: StrokeStyle(lineWidth: 2, dash: [7]))
                            }
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    .frame(width: 68, height: 88)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("갤러리에서 클립 추가")
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 10)
        }
        .frame(height: 108)
    }

    private var durationPicker: some View {
        HStack(spacing: 28) {
            ForEach(durations, id: \.self) { duration in
                Button {
                    selectedDuration = duration
                    showToast("\(duration) 클립 길이를 선택했어요")
                } label: {
                    Text(duration)
                        .font(.system(size: selectedDuration == duration ? 18 : 16, weight: .black))
                        .foregroundStyle(selectedDuration == duration ? Color.maplogInk : .white.opacity(0.82))
                        .frame(width: 46, height: 34)
                        .background(selectedDuration == duration ? Color.white : .clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Image(systemName: "lock.fill")
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(.top, 28)
    }

    private var shutterRow: some View {
        HStack {
            CameraCircleButton(systemImage: "photo.on.rectangle.angled", size: 62) {
                activeToolSheet = .gallery
            }
            Spacer()
            CaptureRecordingShutterButton(
                isRecording: camera.isRecording,
                startedAt: recordingStartedAt,
                duration: activeRecordingDuration,
                action: handleShutter
            )
            Spacer()
            CameraCircleButton(systemImage: "arrow.triangle.2.circlepath.camera", size: 62) {
                camera.switchCamera()
                showToast(camera.isFrontCamera ? "전면 카메라 모드" : "후면 카메라 모드")
            }
        }
        .padding(.horizontal, 42)
        .padding(.top, 20)
    }

    private var nextButton: some View {
        Button {
            guard !capturedStyles.isEmpty else {
                showToast("먼저 클립을 촬영해 주세요")
                return
            }
            showsPlaceMatching = true
        } label: {
            Text("다음")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.maplogInk)
                .frame(width: 112, height: 52)
                .background(Color.maplogCaptureAccent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 22)
        .padding(.bottom, 32)
        .navigationDestination(isPresented: $showsPlaceMatching) {
            PlaceMatchingView(capturedStyles: capturedStyles, initialPlaceName: initialPlaceName)
        }
    }

    private func handleShutter() {
        if camera.isRecording {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            camera.stopRecording()
            return
        }

        if countdown != nil {
            countdownTask?.cancel()
            countdown = nil
            showToast("타이머를 취소했어요")
            return
        }

        let timerSeconds = selectedTimerSeconds
        guard timerSeconds > 0 else {
            recordCurrentClip()
            return
        }

        countdownTask?.cancel()
        countdownTask = Task {
            for value in stride(from: timerSeconds, through: 1, by: -1) {
                await MainActor.run {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                        countdown = value
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.18)) {
                    countdown = nil
                }
                recordCurrentClip()
            }
        }
    }

    private func recordCurrentClip() {
        let transitionSuffix = selectedTransition == "컷" ? "" : " · \(selectedTransition)"
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showToast("\(selectedDuration) 녹화를 시작했어요\(transitionSuffix)")
        camera.recordClip(
            duration: selectedDurationSeconds,
            durationLabel: selectedDuration,
            transition: selectedTransition,
            style: nextClipStyle
        )
    }

    private func importGalleryClip(_ style: PhotoStyle) {
        camera.addImportedClip(style: style, durationLabel: selectedDuration, transition: selectedTransition)
        showToast("최근 사진을 \(camera.recordedClips.count)번째 클립으로 추가했어요")
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            toastText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            withAnimation(.easeOut(duration: 0.2)) {
                toastText = nil
            }
        }
    }
}

private struct CameraCircleButton: View {
    let systemImage: String
    var size: CGFloat = 44
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size > 50 ? 24 : 18, weight: .bold))
                .foregroundStyle(isSelected ? Color.maplogInk : .white)
                .frame(width: size, height: size)
                .background(isSelected ? Color.maplogLime : .black.opacity(0.42))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
    }
}

private struct CaptureGridOverlay: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Rectangle().fill(.white.opacity(0.26)).frame(height: 1)
            Spacer()
            Rectangle().fill(.white.opacity(0.26)).frame(height: 1)
            Spacer()
        }
        .overlay {
            HStack(spacing: 0) {
                Spacer()
                Rectangle().fill(.white.opacity(0.26)).frame(width: 1)
                Spacer()
                Rectangle().fill(.white.opacity(0.26)).frame(width: 1)
                Spacer()
            }
        }
        .ignoresSafeArea()
    }
}

private struct CaptureTextSticker: View {
    let text: String

    var body: some View {
        VStack {
            Text(text)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.black.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.32), lineWidth: 1)
                }
            Spacer()
        }
        .padding(.horizontal, 42)
    }
}

private struct CaptureTimerSheet: View {
    let selectedTimer: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let timers = ["끄기", "3초", "5초", "10초"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sheetHeader(title: "타이머", subtitle: "촬영 전 카운트다운을 선택하세요.")

            HStack(spacing: 10) {
                ForEach(timers, id: \.self) { timer in
                    Button {
                        onSelect(timer)
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: timer == "끄기" ? "timer" : "timer.circle.fill")
                                .font(MaplogFont.screenTitle)
                            Text(timer)
                                .font(.system(size: 14, weight: .black))
                        }
                        .foregroundStyle(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 96)
                        .background(selectedTimer == timer ? Color.maplogLime : Color.maplogCanvas)
                        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                dismiss()
            } label: {
                Text("취소")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.plain)
        }
        .padding(MaplogSpacing.xLarge)
    }

    private func sheetHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(MaplogFont.screenTitle)
                    .foregroundStyle(Color.maplogInk)
                Text(subtitle)
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogMuted)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CaptureTransitionSheet: View {
    let selectedTransition: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let transitions: [(title: String, icon: String)] = [
        ("컷", "rectangle.on.rectangle"),
        ("페이드", "circle.lefthalf.filled"),
        ("줌인", "plus.magnifyingglass"),
        ("플래시", "bolt.fill")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("전환 효과")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text("다음 클립에 적용할 움직임을 고르세요.")
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogMuted)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                ForEach(transitions, id: \.title) { transition in
                    Button {
                        onSelect(transition.title)
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: transition.icon)
                                .font(.system(size: 21, weight: .black))
                            Text(transition.title)
                                .font(.system(size: 13, weight: .black))
                        }
                        .foregroundStyle(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 94)
                        .background(selectedTransition == transition.title ? Color.maplogLime : Color.maplogCanvas)
                        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("선택한 효과는 셔터를 눌러 추가하는 다음 클립부터 목데이터 상태로 반영됩니다.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.maplogMuted)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.maplogCanvas.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
        }
        .padding(MaplogSpacing.xLarge)
    }
}

private struct CaptureTextStickerSheet: View {
    let onApply: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draftText: String

    init(currentText: String, onApply: @escaping (String) -> Void) {
        self.onApply = onApply
        _draftText = State(initialValue: currentText.isEmpty ? "오늘의 맵로그" : currentText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("텍스트 스티커")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text("영상 위에 올릴 짧은 문구를 입력하세요.")
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogMuted)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            TextField("예: 오늘의 맵로그", text: $draftText)
                .font(.system(size: 17, weight: .bold))
                .padding(.horizontal, MaplogSpacing.medium)
                .frame(height: 54)
                .background(Color.maplogCanvas)
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))

            Text(draftText.isEmpty ? "텍스트 미리보기" : draftText)
                .font(MaplogFont.screenTitle)
                .foregroundStyle(.white)
                .lineLimit(2)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.maplogInk)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 10) {
                Button {
                    onApply("")
                } label: {
                    Text("지우기")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: 110, height: 52)
                        .background(Color.maplogCanvas)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    onApply(draftText)
                } label: {
                    Text("적용")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MaplogSpacing.xLarge)
    }
}

private struct CaptureGallerySheet: View {
    let styles: [PhotoStyle]
    let onSelect: (PhotoStyle) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("최근 사진")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text("목 갤러리에서 클립으로 추가할 컷을 선택하세요.")
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogMuted)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(styles.enumerated()), id: \.offset) { index, style in
                    Button {
                        onSelect(style)
                    } label: {
                        CaptureTravelImageView(style: style, cornerRadius: MaplogRadius.medium)
                            .frame(height: 86)
                            .overlay(alignment: .topLeading) {
                                Text("0\(index + 1)")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(Color.maplogInk)
                                    .padding(.horizontal, 7)
                                    .frame(height: 22)
                                    .background(Color.maplogLime)
                                    .clipShape(Capsule())
                                    .padding(7)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(MaplogSpacing.xLarge)
    }
}

struct PlaceMatchingView: View {
    let capturedStyles: [PhotoStyle]
    let initialPlaceName: String?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSpot: MaplogSpot
    @State private var showsManualSearch = false
    private let spots: [MaplogSpot]

    init(capturedStyles: [PhotoStyle], initialPlaceName: String? = nil) {
        self.capturedStyles = capturedStyles
        let trimmedPlaceName = initialPlaceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.initialPlaceName = trimmedPlaceName.isEmpty ? nil : trimmedPlaceName

        if let matchedSpot = Self.matchingSpot(for: trimmedPlaceName) {
            self.spots = [matchedSpot] + MockMaplogData.spots.filter { $0.id != matchedSpot.id }
            _selectedSpot = State(initialValue: matchedSpot)
        } else if !trimmedPlaceName.isEmpty {
            let quickSpot = Self.quickIntentSpot(
                named: trimmedPlaceName,
                fallbackStyle: capturedStyles.last ?? .city
            )
            self.spots = [quickSpot] + MockMaplogData.spots
            _selectedSpot = State(initialValue: quickSpot)
        } else {
            self.spots = MockMaplogData.spots
            _selectedSpot = State(initialValue: MockMaplogData.spots[0])
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("장소 선택")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Spacer()
                    Color.clear.frame(width: 42, height: 42)
                }
                .padding(.horizontal, MaplogSpacing.medium)
                .padding(.top, 6)
                .frame(height: 60)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.maplogLine).frame(height: 1)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        CaptureTravelImageView(style: capturedStyles.last ?? .city, cornerRadius: 18)
                            .frame(width: 112, height: 112)
                            .padding(.top, 28)

                        Text(placeMatchingMessage)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.maplogMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        VStack(spacing: 0) {
                            ForEach(spots.prefix(3)) { spot in
                                PlaceCandidateRow(
                                    spot: spot,
                                    isSelected: selectedSpot.id == spot.id
                                ) {
                                    selectedSpot = spot
                                }
                                if spot.id != spots.prefix(3).last?.id {
                                    Divider().padding(.leading, 54)
                                }
                            }

                            Button {
                                showsManualSearch = true
                            } label: {
                                HStack(spacing: MaplogSpacing.small) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(Color.maplogMuted)
                                    Text("직접 검색하기")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Color.maplogMuted)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .black))
                                        .foregroundStyle(Color.maplogMuted)
                                }
                                .padding(18)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.maplogSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 8)
                        .padding(.horizontal, MaplogSpacing.page)
                    }
                    .padding(.bottom, 132)
                }
            }

            NavigationLink {
                UploadView(spot: selectedSpot, capturedStyles: capturedStyles)
            } label: {
                Text("장소 확정하기")
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
                    .padding(.horizontal, 22)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 22)
            .background(Color.maplogSurface)
        }
        .background(Color.maplogCanvas.opacity(0.34))
        .navigationBarBackButtonHidden()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
        .fullScreenCover(isPresented: $showsManualSearch) {
            NavigationStack {
                MapSearchView(query: initialPlaceName ?? selectedSpot.name) { spot in
                    selectedSpot = spot
                }
            }
        }
    }

    private var placeMatchingMessage: String {
        if initialPlaceName != nil {
            return "빠른 기록으로 받은 장소를 기준으로\n추천된 장소입니다."
        }
        return "사진의 GPS 정보를 기반으로\n추천된 장소입니다."
    }

    private static func matchingSpot(for placeName: String) -> MaplogSpot? {
        let trimmedPlaceName = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPlaceName.isEmpty else { return nil }

        return MockMaplogData.spots.first { spot in
            spot.name.localizedCaseInsensitiveContains(trimmedPlaceName)
                || trimmedPlaceName.localizedCaseInsensitiveContains(spot.name)
                || spot.area.localizedCaseInsensitiveContains(trimmedPlaceName)
                || spot.tags.contains { tag in
                    tag.localizedCaseInsensitiveCompare(trimmedPlaceName) == .orderedSame
                }
        }
    }

    private static func quickIntentSpot(named placeName: String, fallbackStyle: PhotoStyle) -> MaplogSpot {
        let normalizedID = placeName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")

        return MaplogSpot(
            id: "intent-spot-\(normalizedID)",
            name: placeName,
            category: "빠른기록",
            area: "현재 위치 기반",
            summary: "App Intent로 시작한 빠른 기록 장소입니다. 촬영 후 위치 태그를 다시 조정할 수 있어요.",
            rating: 4.6,
            imageStyle: fallbackStyle,
            tags: ["빠른기록", "신규", "Maplog"],
            pinX: 0.50,
            pinY: 0.50
        )
    }
}

private struct PlaceCandidateRow: View {
    let spot: MaplogSpot
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Circle()
                    .stroke(isSelected ? Color.maplogLime : Color.maplogMuted.opacity(0.38), lineWidth: 1.4)
                    .background {
                        if isSelected {
                            Circle().fill(Color.maplogLime)
                                .overlay {
                                    Circle().fill(Color.maplogInk).frame(width: 7, height: 7)
                                }
                        }
                    }
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(spot.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                    Text(spot.area)
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogMuted)
                }

                Spacer()
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.maplogMuted.opacity(0.62))
            }
            .padding(18)
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch spot.category {
        case "카페": return "fork.knife"
        case "문화": return "building.columns"
        default: return "mappin.and.ellipse"
        }
    }
}

private struct ComposerLocationTag: Identifiable, Hashable {
    let id: String
    let name: String
    let timeRange: String
    let style: PhotoStyle

    var draftTag: MaplogDraftLocationTag {
        MaplogDraftLocationTag(
            id: id,
            name: name,
            timeRange: timeRange,
            style: style
        )
    }

    init(id: String, name: String, timeRange: String, style: PhotoStyle) {
        self.id = id
        self.name = name
        self.timeRange = timeRange
        self.style = style
    }

    init(draftTag: MaplogDraftLocationTag) {
        self.id = draftTag.id
        self.name = draftTag.name
        self.timeRange = draftTag.timeRange
        self.style = draftTag.style
    }
}

private enum UploadEditSheet: Identifiable {
    case cover
    case editLocation(String)
    case addLocation

    var id: String {
        switch self {
        case .cover:
            return "cover"
        case .editLocation(let tagID):
            return "edit-\(tagID)"
        case .addLocation:
            return "add-location"
        }
    }
}

struct UploadView: View {
    let spot: MaplogSpot
    let capturedStyles: [PhotoStyle]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var title: String
    @State private var note: String
    @State private var visibility = "전체 공개"
    @State private var tags = ["#Travel", "#Seongsu", "#CafeTour"]
    @State private var tagInput = ""
    @State private var coverStyle: PhotoStyle
    @State private var locationTags: [ComposerLocationTag]
    @State private var activeSheet: UploadEditSheet?
    @State private var toastText: String?
    @State private var showsPreview = false
    @State private var savedDraft: MaplogDraft?

    private let visibilityOptions = ["전체 공개", "친구만", "비공개"]

    init(spot: MaplogSpot, capturedStyles: [PhotoStyle]) {
        self.spot = spot
        self.capturedStyles = capturedStyles
        let initialCoverStyle = capturedStyles.last ?? spot.imageStyle
        let secondaryEndTime = Self.durationTimeCode(for: max(capturedStyles.count * 15, 30))
        var initialLocationTags = [
            ComposerLocationTag(id: "tag-primary", name: spot.name, timeRange: "00:00 - 00:15", style: spot.imageStyle)
        ]
        if capturedStyles.count > 1 {
            initialLocationTags.append(
                ComposerLocationTag(id: "tag-secondary", name: "서울숲", timeRange: "00:16 - \(secondaryEndTime)", style: .forest)
            )
        }
        _title = State(initialValue: "\(spot.name) 맵로그")
        _note = State(initialValue: "\(spot.area)에서 남긴 오늘의 맵로그입니다.")
        _coverStyle = State(initialValue: initialCoverStyle)
        _locationTags = State(initialValue: initialLocationTags)
    }

    init(draft: MaplogDraft) {
        let restoredSpot = Self.restoredSpot(for: draft)
        let restoredStyles = Self.restoredClipStyles(for: draft)
        self.spot = restoredSpot
        self.capturedStyles = restoredStyles
        _title = State(initialValue: draft.title)
        _note = State(initialValue: draft.note)
        _visibility = State(initialValue: draft.visibility)
        _tags = State(initialValue: draft.hashtags.isEmpty ? ["#Draft", "#Maplog", "#Travel"] : draft.hashtags)
        _coverStyle = State(initialValue: draft.imageStyle)
        _locationTags = State(initialValue: Self.restoredLocationTags(for: draft))
        _savedDraft = State(initialValue: draft)
    }

    private var previewDraft: ComposerDraft {
        ComposerDraft(
            placeName: spot.name,
            title: title,
            mood: visibility,
            rating: 5,
            note: note.isEmpty ? "\(spot.area)에서 남긴 오늘의 맵로그입니다." : note,
            imageStyle: coverStyle,
            sourceDraftID: savedDraft?.id,
            clipCount: capturedStyles.count,
            locationTags: locationTags.map(\.draftTag),
            hashtags: tags
        )
    }

    private static func restoredSpot(for draft: MaplogDraft) -> MaplogSpot {
        if let spot = MockMaplogData.spots.first(where: { $0.name == draft.placeName }) {
            return spot
        }

        return MaplogSpot(
            id: "draft-spot-\(draft.id)",
            name: draft.placeName,
            category: "임시저장",
            area: draft.placeName,
            summary: draft.note,
            rating: 5.0,
            imageStyle: draft.imageStyle,
            tags: ["임시저장", "Maplog"],
            pinX: 0.50,
            pinY: 0.50
        )
    }

    private static func restoredClipStyles(for draft: MaplogDraft) -> [PhotoStyle] {
        if !draft.clipStyles.isEmpty {
            return draft.clipStyles
        }

        let fallbackStyles: [PhotoStyle] = [draft.imageStyle, .city, .cafe, .forest, .palace]
        let clipCount = max(draft.clipCount, 1)
        return (0..<clipCount).map { fallbackStyles[$0 % fallbackStyles.count] }
    }

    private static func restoredLocationTags(for draft: MaplogDraft) -> [ComposerLocationTag] {
        if !draft.locationTags.isEmpty {
            return draft.locationTags.map(ComposerLocationTag.init(draftTag:))
        }

        let locationCount = max(draft.locationCount, 1)
        let nearbySpots = MockMaplogData.spots.filter { $0.name != draft.placeName }
        guard !nearbySpots.isEmpty else {
            return [
                ComposerLocationTag(
                    id: "tag-primary",
                    name: draft.placeName,
                    timeRange: restoredTimeRange(for: 0),
                    style: draft.imageStyle
                )
            ]
        }

        return (0..<locationCount).map { index in
            if index == 0 {
                return ComposerLocationTag(
                    id: "tag-primary",
                    name: draft.placeName,
                    timeRange: restoredTimeRange(for: index),
                    style: draft.imageStyle
                )
            }

            let nearbySpot = nearbySpots[(index - 1) % max(nearbySpots.count, 1)]
            return ComposerLocationTag(
                id: "tag-restored-\(index)",
                name: nearbySpot.name,
                timeRange: restoredTimeRange(for: index),
                style: nearbySpot.imageStyle
            )
        }
    }

    private static func restoredTimeRange(for index: Int) -> String {
        let startMinute = index * 15
        let endMinute = startMinute + 15
        return "\(restoredTimeCode(for: startMinute)) - \(restoredTimeCode(for: endMinute))"
    }

    private static func restoredTimeCode(for totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private var coverOptions: [PhotoStyle] {
        var seen: Set<PhotoStyle> = []
        return (capturedStyles + [spot.imageStyle, .city, .cafe, .palace]).filter { style in
            seen.insert(style).inserted
        }
    }

    private var safeClipCount: Int {
        max(capturedStyles.count, 1)
    }

    private var durationText: String {
        "\(safeClipCount)–\(safeClipCount * 2)초"
    }

    private var locationCandidates: [ComposerLocationTag] {
        MockMaplogData.spots.enumerated().map { index, spot in
            ComposerLocationTag(
                id: "candidate-\(spot.id)",
                name: spot.name,
                timeRange: index == 0 ? "추천 장소" : "근처 \(index + 1)순위",
                style: spot.imageStyle
            )
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                        uploadHeader
                        mediaPreview
                        if let savedDraft {
                            draftStatusCard(savedDraft)
                        }
                        locationTagSection
                        titleSection
                        tagSection
                        visibilitySection
                    }
                    .padding(.horizontal, MaplogSpacing.page)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }

                uploadBottomActionBar
            }

            if let toastText {
                Text(toastText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, MaplogSpacing.medium)
                    .frame(height: 44)
                    .background(Color.maplogSurface)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)
                    .padding(.bottom, 86)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.maplogSurface)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
        .navigationDestination(isPresented: $showsPreview) {
            LogPreviewView(draft: previewDraft)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .cover:
                CoverEditSheet(
                    options: coverOptions,
                    selectedStyle: coverStyle,
                    onSelect: { style in
                        coverStyle = style
                        activeSheet = nil
                        showToast("대표 이미지를 변경했어요")
                    }
                )
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            case .editLocation(let tagID):
                LocationTagEditSheet(
                    title: "위치 태그 편집",
                    currentTag: locationTag(for: tagID),
                    candidates: locationCandidates,
                    onSelect: { candidate in
                        updateLocationTag(id: tagID, with: candidate)
                        activeSheet = nil
                    }
                )
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
            case .addLocation:
                LocationTagEditSheet(
                    title: "위치 추가하기",
                    currentTag: ComposerLocationTag(id: "new", name: "새 위치", timeRange: nextLocationTimeRange, style: .city),
                    candidates: locationCandidates,
                    onSelect: { candidate in
                        addLocationTag(candidate)
                        activeSheet = nil
                    }
                )
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var uploadBottomActionBar: some View {
        HStack(spacing: 10) {
            Button {
                saveDraft()
            } label: {
                Text(savedDraft == nil ? "임시저장" : "다시저장")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 118, height: 56)
                    .background(Color.maplogCanvas)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                showsPreview = true
            } label: {
                Text("게시하기")
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color.maplogSurface)
    }

    private var uploadHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Maplog 업로드")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogInk)
            Spacer()
            Button {
                showsPreview = true
            } label: {
                Text("게시")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.maplogLime)
                    .frame(width: 56, height: 36)
                    .background(Color.maplogInk)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func draftStatusCard(_ draft: MaplogDraft) -> some View {
        HStack(spacing: MaplogSpacing.small) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.maplogInk)
                .frame(width: 42, height: 42)
                .background(Color.maplogLime)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("임시저장 완료")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                Text(draft.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(1)
                Text(draft.metadata)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(1)
            }

            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.maplogOlive)
        }
        .padding(14)
        .background(Color.maplogLime.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.maplogLime.opacity(0.42), lineWidth: 1)
        }
    }

    private var mediaPreview: some View {
        CaptureTravelImageView(style: coverStyle, cornerRadius: 18)
            .frame(height: 262)
            .overlay(alignment: .topTrailing) {
                Label(durationText, systemImage: "circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, MaplogSpacing.small)
                    .frame(height: 34)
                    .background(.black.opacity(0.62))
                    .clipShape(Capsule())
                    .padding(MaplogSpacing.small)
            }
            .overlay(alignment: .bottomLeading) {
                Button {
                    activeSheet = .cover
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.9))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(14)
            }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("로그 제목")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.maplogInk)
            TextField("로그 제목을 입력하세요", text: $title)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, MaplogSpacing.medium)
                .frame(height: 56)
                .background(Color.maplogCanvas)
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))

            Text("설명")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.maplogInk)
                .padding(.top, 8)
            TextField("이번 여정에 대해 자유롭게 남겨주세요.", text: $note, axis: .vertical)
                .lineLimit(4...5)
                .font(.system(size: 16, weight: .medium))
                .padding(MaplogSpacing.medium)
                .frame(minHeight: 92, alignment: .top)
                .background(Color.maplogCanvas)
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
        }
    }

    private var locationTagSection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            HStack {
                Label("위치 태그", systemImage: "mappin.circle.fill")
                    .font(MaplogFont.sectionTitle)
                    .foregroundStyle(Color.maplogOlive)
                Spacer()
                Text("자동 매칭됨")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color.maplogCanvas)
                    .clipShape(Capsule())
            }

            ForEach(Array(locationTags.enumerated()), id: \.element.id) { index, tag in
                HStack(spacing: MaplogSpacing.small) {
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.maplogOlive)
                        .frame(width: 34, height: 34)
                        .background(Color.maplogLime.opacity(0.18))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tag.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                        Text(tag.timeRange)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.maplogMuted)
                    }
                    Spacer()
                    Button {
                        activeSheet = .editLocation(tag.id)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.maplogMuted)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .maplogCard()
            }

            Button {
                activeSheet = .addLocation
            } label: {
                Label("위치 추가하기", systemImage: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background {
                        RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous)
                            .stroke(Color.maplogLine, style: StrokeStyle(lineWidth: 1.4, dash: [4]))
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("# 태그")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogOlive)

            VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                FlowChips(items: tags, selectedItem: nil) { tag in
                    tags.removeAll { $0 == tag }
                }
                TextField("태그 입력 후 엔터", text: $tagInput)
                    .font(.system(size: 15, weight: .medium))
                    .submitLabel(.done)
                    .onSubmit(addTag)
            }
            .padding(MaplogSpacing.medium)
            .background(Color.maplogCanvas)
            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
        }
    }

    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Label("공개 설정", systemImage: "eye.fill")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogOlive)
            HStack(spacing: 0) {
                ForEach(visibilityOptions, id: \.self) { option in
                    Button {
                        visibility = option
                    } label: {
                        Text(option)
                            .font(.system(size: 14, weight: visibility == option ? .black : .bold))
                            .foregroundStyle(visibility == option ? Color.maplogInk : Color.maplogMuted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(visibility == option ? .white : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.maplogCanvas)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
        tags.append(normalized)
        tagInput = ""
    }

    private var nextLocationTimeRange: String {
        timeRange(for: locationTags.count)
    }

    private func locationTag(for id: String) -> ComposerLocationTag {
        locationTags.first { $0.id == id } ?? ComposerLocationTag(
            id: "fallback",
            name: spot.name,
            timeRange: "00:00 - 00:15",
            style: spot.imageStyle
        )
    }

    private func updateLocationTag(id: String, with candidate: ComposerLocationTag) {
        guard let index = locationTags.firstIndex(where: { $0.id == id }) else { return }
        let currentTag = locationTags[index]
        locationTags[index] = ComposerLocationTag(
            id: currentTag.id,
            name: candidate.name,
            timeRange: currentTag.timeRange,
            style: candidate.style
        )
        showToast("\(candidate.name)으로 위치를 변경했어요")
    }

    private func addLocationTag(_ candidate: ComposerLocationTag) {
        let newTag = ComposerLocationTag(
            id: "tag-\(locationTags.count)-\(candidate.id)",
            name: candidate.name,
            timeRange: nextLocationTimeRange,
            style: candidate.style
        )
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            locationTags.append(newTag)
        }
        showToast("\(candidate.name)을 위치 태그에 추가했어요")
    }

    private func timeRange(for index: Int) -> String {
        let startMinute = index * 15
        let endMinute = startMinute + 15
        return "\(timeCode(for: startMinute)) - \(timeCode(for: endMinute))"
    }

    private func timeCode(for totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private static func durationTimeCode(for totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            toastText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeOut(duration: 0.2)) {
                toastText = nil
            }
        }
    }

    private func saveDraft() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let draftTitle = trimmedTitle.isEmpty ? "제목 없는 맵로그" : trimmedTitle
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = MaplogDraft(
            id: savedDraft?.id ?? "draft-\(UUID().uuidString)",
            title: draftTitle,
            placeName: spot.name,
            note: trimmedNote.isEmpty ? "\(spot.area)에서 남긴 오늘의 맵로그입니다." : trimmedNote,
            visibility: visibility,
            imageStyle: coverStyle,
            clipCount: capturedStyles.count,
            locationCount: locationTags.count,
            updatedAtText: "방금 저장",
            clipStyles: capturedStyles,
            locationTags: locationTags.map(\.draftTag),
            hashtags: tags
        )
        savedDraft = draft
        sessionStore.saveDraft(draft)
        showToast("임시저장했어요")
    }
}

private struct CoverEditSheet: View {
    let options: [PhotoStyle]
    let selectedStyle: PhotoStyle
    let onSelect: (PhotoStyle) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("대표 이미지")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text("게시물 목록과 공유 카드에 표시될 컷을 선택하세요.")
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogMuted)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MaplogSpacing.small) {
                    ForEach(options, id: \.self) { style in
                        Button {
                            onSelect(style)
                            dismiss()
                        } label: {
                            CaptureTravelImageView(style: style, cornerRadius: 14)
                                .frame(width: 96, height: 128)
                                .overlay(alignment: .topTrailing) {
                                    if selectedStyle == style {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .black))
                                            .foregroundStyle(Color.maplogInk)
                                            .frame(width: 26, height: 26)
                                            .background(Color.maplogLime)
                                            .clipShape(Circle())
                                            .padding(MaplogSpacing.xSmall)
                                    }
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(selectedStyle == style ? Color.maplogLime : Color.clear, lineWidth: 3)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(MaplogSpacing.xLarge)
        .background(Color.maplogSurface)
    }
}

private struct LocationTagEditSheet: View {
    let title: String
    let currentTag: ComposerLocationTag
    let candidates: [ComposerLocationTag]
    let onSelect: (ComposerLocationTag) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text(currentTag.timeRange)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(candidates) { candidate in
                    Button {
                        onSelect(candidate)
                        dismiss()
                    } label: {
                        HStack(spacing: MaplogSpacing.small) {
                            CaptureTravelImageView(style: candidate.style, cornerRadius: 10)
                                .frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(candidate.name)
                                    .font(MaplogFont.cardTitle)
                                    .foregroundStyle(Color.maplogInk)
                                Text(candidate.timeRange)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.maplogMuted)
                            }
                            Spacer()
                            if candidate.name == currentTag.name {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(MaplogFont.screenTitle)
                                    .foregroundStyle(Color.maplogLime)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(Color.maplogMuted)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if candidate.id != candidates.last?.id {
                        Divider().padding(.leading, 78)
                    }
                }
            }
            .background(Color.maplogCanvas.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
        }
        .padding(MaplogSpacing.xLarge)
        .background(Color.maplogSurface)
    }
}
