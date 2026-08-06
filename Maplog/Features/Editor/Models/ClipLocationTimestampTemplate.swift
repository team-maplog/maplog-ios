//
//  ClipLocationTimestampTemplate.swift
//  Maplog
//
//  Created by 한채림 on 8/6/26.
//

import Foundation

enum ClipLocationTimestampTemplate:
    String,
    CaseIterable,
    Equatable,
    Sendable {

    case vlogLine
    case filmCorner
    case lowerThird
    case glassCard
}

//vlogLine
//→ 시간 · mini vlog · 장소를 화면 중앙 한 줄에 배치
//
//filmCorner
//→ 하단 왼쪽에 필름 카메라처럼 작은 날짜·시간·장소 배치
//
//lowerThird
//→ 하단 왼쪽에 여행 브이로그용 장소와 날짜·시간 배치
//
//glassCard
//→ 화면 중앙 반투명 카드 안에 장소와 날짜·시간 배치
