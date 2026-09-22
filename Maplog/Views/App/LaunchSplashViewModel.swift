import Foundation

/// 앱 최초 진입 시 사진 등장 모션과 세션 분기 완료까지만 기다립니다.
/// 홈 API 응답은 시작 화면을 닫는 조건에 포함하지 않습니다.
@MainActor
final class LaunchSplashViewModel: ObservableObject {
    enum Stage {
        case presenting
        case revealing
        case finished
    }

    // 카드 모션 속도는 유지하고, 홈 데이터가 준비될 시간을 1초 더 확보합니다.
    static let entranceDuration: Duration = .milliseconds(2300)
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
