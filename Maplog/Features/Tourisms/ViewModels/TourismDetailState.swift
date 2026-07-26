//
//  TourismDetailState.swift
//  Maplog
//
//  Created by 한채림 on 7/26/26.
// 목록과 달리 상세 조회는 한 콘텐츠만 가져오므로 empty나 다음 페이지 상태가 필요 없음

enum TourismDetailState: Equatable {
    case idle
    case loading
    case content(TourismDetailViewData)
    case failed(ErrorPresentation)
}
