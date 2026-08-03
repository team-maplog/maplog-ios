//
//  ClipEditorState.swift
//  Maplog
//
//  Created by 한채림 on 8/2/26.
// 편집 화면 상태

import Foundation

enum ClipEditorState: Equatable {
    case loading
    case content
    case failed(ErrorPresentation)
}
