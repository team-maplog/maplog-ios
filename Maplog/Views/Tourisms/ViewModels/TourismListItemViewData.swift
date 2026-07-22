//
//  TourismListItemViewData.swift
//  Maplog
//
//  Created by 한채림 on 7/22/26.
//

//Tourism을 그리드 카드에 바로 표시하기 좋게 변환한 데이터
//TourismListItemViewData와 TourismListState 작성
//TourismListViewModel에서 첫 페이지 조회 구현
//TourismListView에서 loading / content / empty / failed 표시
//TourismGridCard로 2열 UI 구성
//마지막 카드 도달 시 nextCursor로 다음 페이지 요청
//홈의 전체보기를 실제 TourismListView로 연결

//Tourism
//├─ id           → TourismListItemViewData.id
//├─ name         → title
//├─ region       → locationText
//├─ startDate/endDate → periodText
//└─ thumbnailURL → thumbnailURL

import Foundation

struct TourismListItemViewData: Identifiable, Equatable {
    let id: Int64
    let title: String
    let locationText: String
    let periodText: String
    let thumbnailURL: URL?
}
