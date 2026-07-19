//
//  AuthViewModel.swift
//  Maplog
//
//  Created by 한채림 on 7/18/26.
//

import Foundation

final class AuthViewModel: ObservableObject {
    @Published var emailError: String?
    @Published var passwordError: String?
    @Published var  passwordConfirmationError: String?
    @Published var  nicknameError: String?
    @Published var  termsError: String?
    
    
}

