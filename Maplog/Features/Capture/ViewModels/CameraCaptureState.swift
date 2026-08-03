//
//  CameraCaptureState.swift
//  Maplog
//
//  Created by 한채림 on 7/31/26.
// 카메라 화면 상태
//idle              아직 카메라 준비 전
//preparing         권한 확인 + 세션 구성 중
//ready             미리보기 표시, 촬영 가능
//countingDown      3·5·10초 시작 타이머 진행 중
//recording         실제 영상 녹화 중
//saving            녹화 종료 후 앱 내부 초안 저장 중
//permissionDenied  카메라 권한 없음
//failed            그 외 기술 오류

import Foundation

enum CameraCaptureState: Equatable {
    case idle
    case preparing
    case ready
    case countingDown(remainingSeconds: Int)
    case recording
    case saving
    case permissionDenied
    case failed(ErrorPresentation)
}
