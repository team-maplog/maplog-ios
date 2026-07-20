//
//  KeychainService.swift
//  Maplog
//
//  Created by 한채림 on 7/18/26.
//

// 토큰 문자열을 저장 조회 삭제하는 도구 역할

//저장: accessToken / refreshToken
//조회: 앱을 다시 켰을 때 토큰이 있는지 확인
//삭제: 로그아웃 또는 토큰 무효 시 제거

//첫 로그인
//→ SecItemUpdate: 찾지 못함
//→ SecItemAdd: 새 access token 저장
//
//두 번째 로그인 / 토큰 갱신
//→ SecItemUpdate: 기존 항목 찾음
//→ 토큰 값만 새 값으로 수정

import Foundation
import Security

enum KeychainService {
    // service는 keychain 안에서 maplog 인증 정보 묶음을 식별하는 이름
    private static let service = "\(Bundle.main.bundleIdentifier ?? "Maplog").auth"
    
    enum KeychainError: Error {
        case unexpectedStatus(OSStatus) // keychain api가 성공 실패를 숫자로 알려주는 타입
        case invalidStoredData
    }
    
    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
    
    // 이미 있으면 값 수정, 없으면 새로 추가
    static func save(
        _ value: String,
        for key: String
    ) throws {
        let data = Data(value.utf8)
        let query = baseQuery(for: key) // 누구를 찾을지 (generic password 종류이면서 maplog 인증 service에 속하고 Maplog.accessToken이라는 account를 가진 항목
        
        let attributesToUpdate: [String: Any] = [ // 찾았다면 무엇을 바꿀지
            kSecValueData as String: data
            ]
        
        // query 조건에 맞는 keychain 항목을 찾아서, attributesToUpdate에 든 값으로 수정해줘
        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        
        if updateStatus == errSecItemNotFound { // 수정하려 했지만, 기존 항목이 없음, 새로 추가하는 부분
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil) // 새 keychain항목을 생성
            
            guard addStatus == errSecSuccess else { // 기존 항목을 찾았고, 토큰 값 수정 성공
                throw KeychainError.unexpectedStatus(addStatus)
            }
            
            return
        }
        // 예상치 못한 오류 처리
        guard updateStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }
   
    // read 함수에서 String?을 반환하는 이유
//    nil
//    → 토큰이 저장된 적 없음
//    → 정상적인 “로그인 안 됨” 상태
//
//    throw
//    → Keychain 접근 자체 실패
//    → 예상하지 못한 오류
    
    // 검색 조건에 데이터도 함께 반환해줘를 추가하는 방식
    static func read(for key: String) throws -> String? {
        var query = baseQuery(for: key) // 어떤 항목을 찾을지
        
        query[kSecReturnData as String] = kCFBooleanTrue // 찾은 항목의 실제 data도 돌려줘
        query[kSecMatchLimit as String] = kSecMatchLimitOne // 여러 개 찾지 말고 하나만 돌려줘
        
        var item: CFTypeRef?
        
        let status = SecItemCopyMatching(query as CFDictionary, &item) // 실제 조회
        
        if status == errSecItemNotFound { // 저장된 토큰이 없음, 로그인하지 않은 상태일 수 있으므로 nil 반환
            return nil
        }
        
        guard status == errSecSuccess else { // 토큰 찾음
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = item as? Data, // 성공한 경우 item에 keychain이 돌려준 Data가 들어있음. 이를 다시 문자열로 바꿔서 반환
              let value = String(data: data, encoding: .utf8) else{
            throw KeychainError.invalidStoredData
        }
        return value
    }
    
    // 로그아웃이나 refresh token 무효 시에는 토큰 삭제
    
    static func delete(for key: String) throws {
        let query = baseQuery(for: key)
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || 
                status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
