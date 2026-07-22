//
//  FestivalPage.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

// API의 content라는 이름 대신 festivals를 씁니다. content는 서버 JSON 용어이고, festivals는 앱 도메인 용어입니다. 이 차이가 DTO와 Domain Model을 분리하는 이유

import Foundation

struct FestivalPage: Equatable {
    let festivals: [Festival]
    let hasNext: Bool
    let nextCursor: String?
}
