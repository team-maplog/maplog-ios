import Foundation

@MainActor
final class SocialConnectionsViewModel: ObservableObject {
    @Published private(set) var connections: [SocialConnection] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var error: ErrorPresentation?
    private let repository: any SocialConnectionRepository

    init(repository: any SocialConnectionRepository) {
        self.repository = repository
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
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
