import Foundation

/// 보호 API의 인증·재발급·한 번의 재시도를 담당한다.
/// 화면과 Repository는 토큰 및 세션 세대를 직접 다루지 않는다.
final class AuthenticatedAPIClient {
    private let apiClient: APIClient
    private let authSession: any AuthSessionManaging
    private let tokenRefresher: any AccessTokenRefreshing

    init(apiClient: APIClient, authSession: any AuthSessionManaging,
         tokenRefresher: any AccessTokenRefreshing) {
        self.apiClient = apiClient
        self.authSession = authSession
        self.tokenRefresher = tokenRefresher
    }

    func request<Response: Decodable>(
        _ request: URLRequest, responseType: Response.Type
    ) async throws -> Response {
        try await perform(request) { request in
            try await self.apiClient.request(request, responseType: responseType)
        }
    }

    func data(for request: URLRequest) async throws -> Data {
        try await perform(request) { try await self.apiClient.data(for: $0) }
    }

    func download(for request: URLRequest) async throws -> URL {
        var downloadedFile: URL?
        do {
            return try await perform(request) {
                let file = try await self.apiClient.download(for: $0)
                downloadedFile = file
                return file
            }
        } catch {
            if let downloadedFile { try? FileManager.default.removeItem(at: downloadedFile) }
            throw error
        }
    }

    private func perform<Value>(
        _ request: URLRequest,
        operation: (URLRequest) async throws -> Value
    ) async throws -> Value {
        let generation = await authSession.sessionGeneration
        let authorized = try await authorize(request, generation: generation)
        do {
            let value = try await operation(authorized.request)
            try await checkSession(generation)
            return value
        } catch {
            try await checkSession(generation)
            guard backendErrorCode(from: error) == .expiredAccessToken else {
                await endSessionIfNeeded(for: error, generation: generation)
                throw error
            }
        }
        do {
            try await refreshIfNeeded(generation: generation, failedToken: authorized.token)
            let retry = try await authorize(request, generation: generation)
            let value = try await operation(retry.request)
            try await checkSession(generation)
            return value
        } catch {
            try await checkSession(generation)
            await endSessionIfNeeded(for: error, generation: generation)
            throw error
        }
    }

    @MainActor
    private func authorize(_ request: URLRequest, generation: UUID) throws
        -> (request: URLRequest, token: String) {
        try checkSession(generation)
        guard let token = try authSession.currentAccessToken(), !token.isEmpty else {
            throw APIError.missingAccessToken
        }
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return (request, token)
    }

    @MainActor
    private func refreshIfNeeded(generation: UUID, failedToken: String) async throws {
        try checkSession(generation)
        // 다른 요청이 이미 갱신했다면 오래된 401 때문에 다시 회전하지 않는다.
        guard try authSession.currentAccessToken() == failedToken else { return }
        try await tokenRefresher.refreshAccessToken()
        try checkSession(generation)
    }

    @MainActor
    private func checkSession(_ generation: UUID) throws {
        guard authSession.sessionGeneration == generation else { throw CancellationError() }
    }

    private func backendErrorCode(from error: Error) -> BackendErrorCode? {
        guard case let APIError.server(_, response) = error else { return nil }
        return BackendErrorCode(serverCode: response.code)
    }

    @MainActor
    private func endSessionIfNeeded(for error: Error, generation: UUID) {
        guard authSession.sessionGeneration == generation else { return }
        if case APIError.missingRefreshToken = error {
            try? authSession.endSession()
        } else if backendErrorCode(from: error) == .invalidAuthentication {
            try? authSession.endSession()
        }
    }
}
