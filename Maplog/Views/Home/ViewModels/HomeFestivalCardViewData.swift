//
//  HomeFestivalCardViewData.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//
//Home 전용 카드 모델
//View가 region == nil을 처리하거나 날짜를 문자열로 바꾸면 View가 너무 많은 일을 하게 됩니다. ViewModel이 이미 가공된 값을 주고, 카드는 그리기만 하게 만듦
//Festival을 HomeFestivalCardViewData로 바꾸는 함수이고, 홈 카드가 바로 보여 주기 편한 형태로 가공하기 위해 존재

import Foundation

struct HomeFestivalCardViewData: Identifiable, Equatable {
    let id: Int64
    let title: String
    let locationText: String
    let periodText: String
    let thumbnailURL: URL?
}

