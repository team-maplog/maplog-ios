//
//  CameraCaptureServiceError.swift
//  Maplog
//
//  Created by 한채림 on 7/31/26.
//

//View
//  → ViewModel: 3초 카운트다운·2초 자동 종료를 결정
//  → CameraCaptureService: 권한·전환·플래시·실제 녹화
//  → MediaDraftRepository: 완성된 임시 파일 저장

import Foundation

enum CameraCaptureServiceError: Error {
    case cameraPermissionDenied
    case sessionNotConfigured
    case cameraUnavailable
    case recordingAlreadyInProgress
    case noActiveRecording
    case recordingFailed
    case torchUnavailable
}
