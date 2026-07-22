//
//  FestivalListState.swift
//  Maplog
//
//  Created by 한채림 on 7/22/26.
//

//처음 로딩 / 내용 / 빈 목록 / 실패 상태

enum FestivalListState: Equatable {
    case idle // 아직 목록 조회를 시작하지 않음
    case initialLoading // 첫 페이지를 불러오는 중, 아직 보여 줄 카드가 없음
    case content // 카드가 한 개 이상 있음
    case empty // 첫 페이지 조회는 성공했지만 축제가 없음
    case failed(message: String) // 첫 페이지 조회 실패, 실패 문구와 재시도 버튼 표시
}
