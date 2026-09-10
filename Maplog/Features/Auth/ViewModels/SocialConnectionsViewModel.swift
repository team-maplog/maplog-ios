import Foundation

@MainActor
final class SocialConnectionsViewModel: ObservableObject {
    @Published private(set) var connections: [SocialConnection] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var error: ErrorPresentation?
    @Published private(set) var disconnectingProvider: String?
    @Published private(set) var disconnectError: ErrorPresentation?
    private let repository: any SocialConnectionRepository

    init(repository: any SocialConnectionRepository) {
        self.repository = repository
    }

    func disconnect(_ connection: SocialConnection) async {
        guard disconnectingProvider == nil, !isLoading, connection.isConnected else { return }
        disconnectingProvider = connection.provider
        disconnectError = nil
        defer { disconnectingProvider = nil }
        do {
            // 서버가 provider revoke와 마지막 로그인 수단 보호를 완료한 뒤에만 목록에서 제거한다.
            try await repository.disconnect(provider: connection.provider)
            connections.removeAll { $0.provider == connection.provider }
        } catch {
            disconnectError = SocialConnectionErrorPolicy.disconnectPresentation(for: error)
        }
    }

    func load() async {
        guard !isLoading, disconnectingProvider == nil else { return }
        isLoading = true
        error = nil
        disconnectError = nil
        defer { isLoading = false }
        do {
            let result = try await repository.fetchConnections()
            try Task.checkCancellation()
            connections = result
            hasLoaded = true
        } catch is CancellationError {
            return
        } catch {
            // 새로고침 실패로 이미 보이던 연결 계정을 지우지 않는다.
            self.error = SocialConnectionErrorPolicy.presentation(for: error)
        }
    }
}
