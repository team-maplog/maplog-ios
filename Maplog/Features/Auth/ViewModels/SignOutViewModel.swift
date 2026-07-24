//
//  Untitled.swift
//  Maplog
//
//  Created by 한채림 on 7/25/26.
//
//서버 로그아웃 성공
//→ 로컬 세션 삭제
//
//토큰 만료·무효
//→ 서버 요청은 실패했지만
//→ 로컬 세션 삭제
//
//네트워크·서버 오류
//→ 로컬 세션 유지
//→ 오류 문구와 재시도

import Foundation

@MainActor
final class SignOutViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var recoveryAction: ErrorPresentation.RecoveryAction?

    private let authRepository: any AuthRepository
    private let authSessionStore: AuthSessionStore

    init(
        authRepository: any AuthRepository,
        authSessionStore: AuthSessionStore
    ) {
        self.authRepository = authRepository
        self.authSessionStore = authSessionStore
    }

    func signOut() async {
        guard !isLoading else {
            return
        }

        clearErrorState()
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            try await authRepository.signOut()
            endLocalSession() // 서버 로그아웃 성공 뒤에도 호출
        } catch {
            handleRemoteSignOutError(error)
        }
    }

    private func handleRemoteSignOutError(_ error: Error) {
        let presentation = SignOutErrorPolicy.presentation(for: error)

        if presentation.shouldEndLocalSession {
            endLocalSession()
        } else {
            apply(presentation)
        }
    }

    private func endLocalSession() {
        do {
            try authSessionStore.endSession()
        } catch {
            errorMessage = "기기에 저장된 로그인 정보를 정리하지 못했어요. 다시 시도해 주세요."
            recoveryAction = .retry
        }
    }

    private func apply(_ presentation: SignOutErrorPresentation) {
        errorMessage = presentation.message
        recoveryAction = presentation.recoveryAction
    }

    private func clearErrorState() {
        errorMessage = nil
        recoveryAction = nil
    }
}
