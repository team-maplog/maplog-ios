import Foundation

/// 사진 등장 모션과 세션 분기 완료까지만 기다립니다.
/// 홈 API 응답은 시작 화면을 닫는 조건에 포함하지 않습니다.
@MainActor
final class LaunchSplashViewModel: ObservableObject {
    enum Stage {
        case presenting
        case revealing
        case finished
    }

    static let entranceDuration: Duration = .milliseconds(1300)
    static let revealDuration: Duration = .milliseconds(500)

    @Published private(set) var stage: Stage = .presenting
    @Published private(set) var presentationID = UUID()
    private var hasFinishedEntrance = false
    private var isDestinationReady = false

    var isVisible: Bool { stage != .finished }

    func prepareForHome() {
        // 저장된 세션을 복원하는 동안 이미 시작한 모션은 다시 재생하지 않습니다.
        guard stage != .presenting else { return }
        hasFinishedEntrance = false
        isDestinationReady = false
        presentationID = UUID()
        stage = .presenting
    }

    func entranceDidFinish() {
        hasFinishedEntrance = true
        revealIfReady()
    }

    func destinationDidBecomeReady() {
        isDestinationReady = true
        revealIfReady()
    }

    func revealDidFinish() {
        guard stage == .revealing else { return }
        stage = .finished
    }

    private func revealIfReady() {
        guard stage == .presenting, hasFinishedEntrance, isDestinationReady else { return }
        stage = .revealing
    }
}
