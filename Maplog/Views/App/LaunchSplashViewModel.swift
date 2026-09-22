import Foundation

/// 시작 화면의 최소 등장 시간과 목적지 준비 상태를 합칩니다.
/// 네트워크 응답 자체는 HomeViewModel이 소유하며, 대기 제한 후에도 조회를 계속합니다.
@MainActor
final class LaunchSplashViewModel: ObservableObject {
    enum Stage {
        case presenting
        case revealing
        case finished
    }

    static let entranceDuration: Duration = .milliseconds(1300)
    static let homeWaitLimit: Duration = .seconds(4)
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
