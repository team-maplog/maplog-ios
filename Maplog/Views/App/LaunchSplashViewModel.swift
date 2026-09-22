import Foundation

/// 앱 최초 진입 시 카드 등장과 목적지 준비를 모두 기다립니다.
/// 홈으로 진입할 때는 관광 조회 결과가 준비된 뒤 목적지 완료 신호를 받습니다.
@MainActor
final class LaunchSplashViewModel: ObservableObject {
    enum Stage {
        case presenting
        case revealing
        case finished
    }

    static let entranceDuration: Duration = .milliseconds(1300)
    static let revealDuration: Duration = .milliseconds(220)

    @Published private(set) var stage: Stage = .presenting
    private var hasFinishedEntrance = false
    private var isDestinationReady = false

    var isVisible: Bool { stage != .finished }

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
