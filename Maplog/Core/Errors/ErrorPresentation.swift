//
//  ErrorPresentation.swift
//  Maplog
//
//  Created by 한채림 on 7/23/26.
//
//APIError
//= 기술적인 실패 정보
//= HTTP 상태, 서버 코드, 디코딩 실패 등
//
//ErrorPresentation
//= 화면 표시 정보
//= 사용자 문구, 재시도 버튼 유무

//ErrorPresentation(
//  message: "인터넷 연결을 확인한 뒤 다시 시도해 주세요.",
//  recoveryAction: .retry
//)

struct ErrorPresentation: Equatable {
    enum RecoveryAction: Equatable {
        case retry
        case signIn
        case none
    }

    let message: String
    let recoveryAction: RecoveryAction
}
