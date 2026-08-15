//
//  AuthenticatedAPIClient.swift
//  Maplog
//
//  Created by 한채림 on 7/28/26.
// 복구 불가 인증 오류에서 세션 종료만 필요
// 보호 API(로그인한 사용자만 호출할 수 있는 API) 전용 실행기입니다. APIClient를 대체하지 않고 감싸는 역할

import Foundation

final class AuthenticatedAPIClient {
    private let apiClient: APIClient
    private let authSession: any AuthSessionManaging
    private let tokenRefresher: any AccessTokenRefreshing

    init(
        apiClient: APIClient,
        authSession: any AuthSessionManaging,
        tokenRefresher: any AccessTokenRefreshing
    ) {
        self.apiClient = apiClient
        self.authSession = authSession
        self.tokenRefresher = tokenRefresher
    }

    // Access Token을 붙여서 요청을 딱 한 번 보내기
    private func requestWithAccessToken<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {
        var authorizedRequest = request

        let accessToken = try await authSession.currentAccessToken()

        guard let accessToken, !accessToken.isEmpty else {
            throw APIError.missingAccessToken
        }

        authorizedRequest.setValue(
                "Bearer \(accessToken)",
                forHTTPHeaderField: "Authorization"
            )

        return try await apiClient.request(authorizedRequest, responseType: responseType)
    }

    private func dataWithAccessToken(
        _ request: URLRequest
    ) async throws -> Data {
        var authorizedRequest = request

        let accessToken = try await authSession.currentAccessToken()

        guard let accessToken, !accessToken.isEmpty else {
            throw APIError.missingAccessToken
        }

        authorizedRequest.setValue(
            "Bearer \(accessToken)",
            forHTTPHeaderField: "Authorization"
        )

        return try await apiClient.data(
            for: authorizedRequest
        )
    }

    private func downloadWithAccessToken(
        _ request: URLRequest
    ) async throws -> URL {
        var authorizedRequest = request

        let accessToken = try await authSession.currentAccessToken()

        guard let accessToken, !accessToken.isEmpty else {
            throw APIError.missingAccessToken
        }

        authorizedRequest.setValue(
            "Bearer \(accessToken)",
            forHTTPHeaderField: "Authorization"
        )

        return try await apiClient.download(
            for: authorizedRequest
        )
    }

    // 오류 코드 확인 메서드
    private func backendErrorCode(from error: Error) -> BackendErrorCode? {
        guard case let APIError.server(_, response) = error else {
            return nil
        }

        return BackendErrorCode(serverCode: response.code)
    }

    // 세션을 끝내야 하는 오류 확인
    private func shouldEndSession(for error: Error) -> Bool {
        if case APIError.missingRefreshToken = error {
            return true
        }

        return backendErrorCode(from: error) == .invalidAuthentication
    }
    
//    오류 수신
//    → 세션 종료 대상인지 검사
//    → 맞으면 AuthSessionStore에게 세션 종료 요청
//    → 이미 종료된 상태라면 AuthSessionStore가 즉시 return
    private func endSessionIfNeeded(
        for error: Error
    ) async {
        guard shouldEndSession(for: error) else {
            return
        }

        try? await authSession.endSession()
    }


//    첫 요청 만료
//    → 재발급 1회
//    → 원래 요청 재시도 1회
//    → 또 실패해도 재발급 반복 없음
    // 인증된 요청 전체 흐름을 관리하기, 만료 시 재발급과 재시도를 결정하는 관리자
    func request<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type) async throws -> Response {
            do {
                return try await requestWithAccessToken(request, responseType: responseType)
            } catch {
                guard backendErrorCode(from: error) == .expiredAccessToken else {
                    await endSessionIfNeeded(for: error)
                    throw error
                }
                do {
                    try await tokenRefresher.refreshAccessToken()
                } catch {
                    await endSessionIfNeeded(for: error)
                    throw error
                }

                do{
                    return try await requestWithAccessToken(request, responseType: responseType)
                } catch { // 재시도 요청의 복구 불가 오류 처리
                    await endSessionIfNeeded(for: error)
                    throw error
                }
            }
        }

//    썸네일 요청
//    → Access Token 첨부
//    → 401 EXPIRED_TOKEN이면 재발급 1회
//    → 같은 썸네일 요청 재시도 1회
    func data(
        for request: URLRequest
    ) async throws -> Data {
        do {
            return try await dataWithAccessToken(request)

        } catch {
            guard backendErrorCode(from: error) == .expiredAccessToken else {
                await endSessionIfNeeded(for: error)

                throw error
            }

            do {
                try await tokenRefresher.refreshAccessToken()
            } catch {
                await endSessionIfNeeded(for: error)

                throw error
            }

            do {
                return try await dataWithAccessToken(request)
            } catch {
                await endSessionIfNeeded(for: error)

                throw error
            }
        }
    }

    func download(
        for request: URLRequest
    ) async throws -> URL {
        do {
            return try await downloadWithAccessToken(request)

        } catch {
            guard backendErrorCode(from: error) == .expiredAccessToken else {
                await endSessionIfNeeded(for: error)

                throw error
            }

            do {
                try await tokenRefresher.refreshAccessToken()
            } catch {
                await endSessionIfNeeded(for: error)

                throw error
            }

            do {
                return try await downloadWithAccessToken(request)
            } catch {
                await endSessionIfNeeded(for: error)

                throw error
            }
        }
    }

}
