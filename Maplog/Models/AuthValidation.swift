//
//  AuthValidation.swift
//  Maplog
//
//  Created by 한채림 on 7/19/26.
//

import Foundation

enum AuthValidation {
    static func emailError(for email: String) -> String? {
        // 이메일 앞뒤 공백제거
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard  !trimmedEmail.isEmpty else {
            return "이메일을 입력해주세요."
        }
        
        guard email.count <= 150 else {
            return "이메일은 150자 이하로 입력해주세요."
        }
    
        guard email.range(
                of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#,
                options: .regularExpression
            ) != nil else {
                return "올바른 이메일 주소를 입력해주세요."
            }
        
        return nil
    }
    
    static func passwordError(for password: String) -> String? {
        guard !password.isEmpty else {
            return "비밀번호를 입력해주세요."
        }
        // 비밀번호 안에서 공백 탭 줄바꿈 문자를 찾을 수 없다.
        guard password.range(of: "\\s", options: .regularExpression) == nil else {
            return "비밀번호에는 공백을 사용할 수 없습니다."
        }
        
        guard (8...72).contains(password.count) else {
            return "비밀번호는 8자 이상 72자 이하로 입력해주세요."
        }
        
        guard password.range(of: "[a-z]", options: .regularExpression) != nil else {
            return "영문 소문자를 1자 이상 포함해주세요."
        }
        
        guard password.range(of: "\\d", options: .regularExpression) != nil else {
            return "숫자를 1자 이상 포함해주세요."
        }
        
        guard password.range(
            of: "[^\\p{L}\\p{N}\\s]",
            options: .regularExpression
        ) != nil else {
            return "특수문자를 1자 이상 포함해주세요."
        }
        
        return nil
    }
    
    static func passwordConfirmationError(password: String, confirmation: String) -> String? {
        
        guard !confirmation.isEmpty else {
            return "비밀번호를 한번 더 입력해주세요."
        }
        
        guard password == confirmation else {
            return "비밀번호가 일치하지 않습니다."
        }
        
        return nil
    }
    
    static func nicknameError(for nickname: String) -> String? {
        
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedNickname.isEmpty else {
            return "닉네임을 입력해주세요."
        }
        
        guard (2...20).contains(nickname.count) else {
            return "닉네임은 2자 이상 20자 이하로 입력해주세요."
        }
        
        guard nickname.range(
                of: #"^[\p{L}\p{N}]+(?: [\p{L}\p{N}]+)*$"#,
                options: .regularExpression
            ) != nil else {
                return "닉네임은 한글, 영문, 숫자와 단일 공백만 사용할 수 있습니다."
            }
        
        return nil
    }
    
    static func termsError(termsAgreed: Bool) -> String? {
        
        guard termsAgreed else {
            return "이용약관에 동의해주세요."
        }
        
        return nil
    }
    
    static func privacyPolicyError(privacyPolicyAgreed: Bool) -> String? {
        
        guard privacyPolicyAgreed else {
            return "개인정보 처리방침에 동의해주세요."
        }
        
        return nil
    }
}

