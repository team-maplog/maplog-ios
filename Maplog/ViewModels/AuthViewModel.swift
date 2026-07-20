//
//  AuthViewModel.swift
//  Maplog
//
//  Created by 한채림 on 7/18/26.
//

import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var emailError: String?
    @Published var passwordError: String?
    @Published var passwordConfirmationError: String?
    @Published var nicknameError: String?
    @Published var termsError: String?
    @Published var privacyPolicyError: String?
    
    @Published var email = ""
    @Published var password = ""
    @Published var passwordConfirmation = ""
    @Published var nickname = ""
    @Published var termsAgreed = false
    @Published var privacyPolicyAgreed = false
    
    @Published var isLoading = false
    @Published var signupError: String?
    
    private let authService: AuthService
    private let authSessionStore: AuthSessionStore
    
    init(authSessionStore: AuthSessionStore, authService: AuthService = AuthService()) {
        self.authSessionStore = authSessionStore
        self.authService = authService
    }
    
    func validateSignupForm() -> Bool {
        
        emailError = AuthValidation.emailError(for: email)
        passwordError = AuthValidation.passwordError(for: password)
        passwordConfirmationError = AuthValidation.passwordConfirmationError(password: password, confirmation: passwordConfirmation)
        nicknameError = AuthValidation.nicknameError(for: nickname)
        termsError = AuthValidation.termsError(termsAgreed:termsAgreed)
        privacyPolicyError = AuthValidation.privacyPolicyError(privacyPolicyAgreed: privacyPolicyAgreed)
        
        guard emailError == nil,
                   passwordError == nil,
                   passwordConfirmationError == nil,
                   nicknameError == nil,
                   termsError == nil,
                    privacyPolicyError == nil
        else {
            return false
        }
        return true
    }
    
    func signUp() async {
        guard !isLoading else {
            return
        }
        
        signupError = nil
        
        guard validateSignupForm() else {
            return
        }
        
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        let request = SignupRequest(email: email,
                                    password: password,
                                    passwordConfirmation: passwordConfirmation,
                                    nickname: nickname,
                                    termsAgreed: termsAgreed,
                                    privacyPolicyAgreed: privacyPolicyAgreed)
        
        do {
            let signupData = try await authService.signUp(request: request)
            // 여기까지 오면 회원가입 API 성공
            // signupData 안에 userId, name, token이 들어 있음
            // 다음 단계에서 JWT를 Keychain에 저장할 예정
            
            // 토큰 keychain 저장 isAuthenticated = true
            try authSessionStore.startSession(with: signupData.token)
            
        } catch let error as APIError {
            switch error {
            case .server(_, response: let response):
                signupError = response.message
                
            case .network:
                signupError = "네트워크 연결을 확인한 뒤 다시 시도해주세요."
                
            default:
                signupError = "회원가입 처리 중 오류가 발생했습니다."
            }
        } catch {
            // JSONEncoder 등에서 발생할 수 있는 예상 밖의 오류
                signupError = "회원가입 처리 중 오류가 발생했습니다."
        }
        
    }
}

