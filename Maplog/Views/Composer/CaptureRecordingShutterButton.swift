import SwiftUI

struct CaptureRecordingShutterButton: View {
    let isRecording: Bool
    let startedAt: Date?
    let duration: TimeInterval
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                recordingRing

                RoundedRectangle(
                    cornerRadius: isRecording ? 13 : 44,
                    style: .continuous
                )
                .fill(isRecording ? Color.red : Color.maplogCaptureAccent)
                .frame(
                    width: isRecording ? 44 : 60,
                    height: isRecording ? 44 : 60
                )
            }
            .frame(width: 84, height: 84)
            .contentShape(Circle())
        }
        .buttonStyle(CaptureShutterPressStyle())
        .accessibilityLabel(isRecording ? "촬영 중지" : "촬영 시작")
        .accessibilityValue(recordingAccessibilityValue)
        .accessibilityHint(isRecording ? "탭하면 현재 촬영을 저장합니다." : "탭하면 선택한 길이만큼 촬영합니다.")
    }

    @ViewBuilder
    private var recordingRing: some View {
        if isRecording, let startedAt {
            TimelineView(.periodic(from: .now, by: reduceMotion ? 0.25 : 1.0 / 30.0)) { context in
                let progress = min(
                    max(context.date.timeIntervalSince(startedAt) / max(duration, 0.1), 0),
                    1
                )

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.34), lineWidth: 5)
                    Circle()
                        .trim(from: 0.001, to: max(progress, 0.001))
                        .stroke(
                            .white,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                .padding(2)
            }
        } else {
            Circle()
                .stroke(.white, lineWidth: 5)
                .padding(2)
        }
    }

    private var recordingAccessibilityValue: String {
        guard isRecording else { return "대기 중" }
        return "녹화 진행 중, " + String(format: "%.1f", duration) + "초 클립"
    }
}

private struct CaptureShutterPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
