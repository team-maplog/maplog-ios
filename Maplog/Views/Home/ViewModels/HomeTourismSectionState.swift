//
//  HomeTourismSectionState.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

//홈 관광 섹션 상태 만들기

enum HomeTourismSectionState: Equatable {
    case idle // 아직 요청하지 않음
    case loading // 첫 API 요청 중
    case content([HomeTourismCardViewData]) //카드 표시
    case empty // API는 성공했지만 content가 []
    case failed(message: String) // 네트워크, TOUR-001, TOUR-002 등 실패
}
