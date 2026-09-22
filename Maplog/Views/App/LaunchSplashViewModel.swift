import Foundation

/// 앱을 처음 열 때 세션 확인까지만 가립니다.
/// 홈 조회나 사진 등장 모션의 완료는 화면 진입 조건이 아닙니다.
@MainActor
final class LaunchSplashViewModel: ObservableObject {
    enum Stage {
        case presenting
        case revealing
        case finished
    }

    static let revealDuration: Duration = .milliseconds(150)

    @Published private(set) var stage: Stage = .presenting

    var isVisible: Bool { stage != .finished }

    func destinationDidBecomeReady() {
        guard stage == .presenting else { return }
        stage = .revealing
    }

    func revealDidFinish() {
        guard stage == .revealing else { return }
        stage = .finished
    }
}
