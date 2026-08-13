//
//  HomeReelSectionState.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// 홈 릴스 상태

enum HomeReelSectionState: Equatable {
    case idle
    case loading
    case content([HomeReelViewData])
    case empty
    case failed(ErrorPresentation)
}
