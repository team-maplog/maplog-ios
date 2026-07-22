//
//  FestivalListItemViewData.swift
//  Maplog
//
//  Created by 한채림 on 7/22/26.
//

//Festival을 그리드 카드에 바로 표시하기 좋게 변환한 데이터
//FestivalListItemViewData와 FestivalListState 작성
//FestivalListViewModel에서 첫 페이지 조회 구현
//FestivalListView에서 loading / content / empty / failed 표시
//FestivalGridCard로 2열 UI 구성
//마지막 카드 도달 시 nextCursor로 다음 페이지 요청
//홈의 전체보기를 실제 FestivalListView로 연결

//Festival
//├─ id           → FestivalListItemViewData.id
//├─ name         → title
//├─ region       → locationText
//├─ startDate/endDate → periodText
//└─ thumbnailURL → thumbnailURL

import Foundation

struct FestivalListItemViewData: Identifiable, Equatable {
    let id: Int64
    let title: String
    let locationText: String
    let periodText: String
    let thumbnailURL: URL?
}

