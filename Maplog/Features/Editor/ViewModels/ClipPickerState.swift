//
//  ClipPickerState.swift
//  Maplog
//
//  Created by 한채림 on 8/1/26.
//
//loading: 저장된 클립 목록을 읽는 중
//content: 하나 이상 있어서 목록 표시 가능
//empty: 아직 촬영한 클립이 없음
//failed: 파일 목록을 읽지 못함

import Foundation

enum ClipPickerState: Equatable {
    case loading
    case content
    case empty
    case failed(ErrorPresentation)
}
