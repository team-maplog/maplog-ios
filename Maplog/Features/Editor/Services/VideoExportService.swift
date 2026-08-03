//
//  VideoExportService.swift
//  Maplog
//
//  Created by 한채림 on 8/3/26.
//
//ViewModel: 클립 순서와 화면 상태 관리
//VideoExportService: 영상 URL을 합쳐 파일 생성
//View: 내보내기 버튼·진행 상태 표시

import Foundation

protocol VideoExportService: Sendable { // 영상 URL을 합쳐 파일 생성
    func export(
        request: VideoExportRequest
    ) async throws -> VideoExportResult
}

//VideoExportRequest
//├── clips: 어떤 원본을 어떤 순서로 합칠지
//└── textOverlays: 어느 클립의 어느 시간에 어떤 자막을 넣을지
