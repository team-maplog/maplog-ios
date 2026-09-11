import SwiftUI

// 상세마다 독립 재생기를 생성해, 뒤에 남은 편집·상세 화면과 출력/진행률을 공유하지 않습니다.
// 구현체 생성은 MaplogApp에서만 담당합니다.
private struct LogPlaybackServiceFactoryKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> any VideoPlaybackService)? = nil
}

private struct PublicLogDestinationKey: EnvironmentKey {
    static let defaultValue: (@MainActor (Int64) -> AnyView)? = nil
}

extension EnvironmentValues {
    var makeLogPlaybackService: (@MainActor () -> any VideoPlaybackService)? {
        get { self[LogPlaybackServiceFactoryKey.self] }
        set { self[LogPlaybackServiceFactoryKey.self] = newValue }
    }

    var publicLogDestination: (@MainActor (Int64) -> AnyView)? {
        get { self[PublicLogDestinationKey.self] }
        set { self[PublicLogDestinationKey.self] = newValue }
    }
}
