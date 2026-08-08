//
//  ClipTextStyle.swift
//  Maplog
//
//  Created by 한채림 on 8/4/26.
//

//고딕 — 기본, 정보 전달용
//둥근 고딕 — 일상 브이로그 느낌
//명조 — 감성적인 여행 문구
//모노스페이스 — 날짜·시간·좌표 느낌
//
//색상은 아래 9개
//흰색, 검정
//Maplog 라임
//노랑, 코랄
//핑크, 라벤더
//하늘, 민트

import Foundation

enum ClipTextFont: String, CaseIterable, Equatable, Sendable {
    case standard
    case rounded
    case serif
    case monospaced
}

enum ClipTextWeight: String, CaseIterable, Equatable, Sendable {
    case regular
    case medium
    case semibold
    case bold
}

enum ClipTextColor: String, CaseIterable, Equatable, Sendable {
    case white
    case black
    case maplogLime
    case warmYellow
    case coral
    case pink
    case lavender
    case skyBlue
    case mint
}

enum ClipTextContainerStyle: Equatable, Sendable {
    case none
    case glass
}

struct ClipTextStyle: Equatable, Sendable {
    static let minimumFontSize = 10.0
    static let maximumFontSize = 52.0

    var font: ClipTextFont
    var weight: ClipTextWeight
    var color: ClipTextColor
    var fontSize: Double
    var containerStyle: ClipTextContainerStyle

    init(
        font: ClipTextFont = .standard,
        weight: ClipTextWeight = .regular,
        color: ClipTextColor = .white,
        fontSize: Double = 26,
        containerStyle: ClipTextContainerStyle = .none
    ) {
        self.font = font
        self.weight = weight
        self.color = color
        self.containerStyle = containerStyle
        self.fontSize = min(
            max(fontSize, Self.minimumFontSize),
            Self.maximumFontSize
        )
    }
}
