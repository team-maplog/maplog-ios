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
    
    func validateSignupForm() -> Bool {
        
        emailError = AuthValidation.emailError(for: email)
        passwordError = AuthValidation.passwordError(for: password)
        passwordConfirmationError = AuthValidation.passwordConfirmationError(password: password, confirmation: passwordConfirmation)
        nicknameError = AuthValidation.nicknameError(for: nickname)
        termsError = AuthValidation.termsError(hasAcceptedTerms: termsAgreed)
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
}

