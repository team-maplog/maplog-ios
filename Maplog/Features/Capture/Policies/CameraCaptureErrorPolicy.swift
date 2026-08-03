//
//  CameraCaptureErrorPolicy.swift
//  Maplog
//
//  Created by 한채림 on 7/31/26.
//
//Service     기술 오류 발생
//Policy      기술 오류 → 사용자 문구 변환
//ViewModel   state를 .failed(...)로 변경
//View        문구와 재시도 버튼만 그림

import Foundation

enum CameraCaptureErrorPolicy {
    static func presentation(for error: Error) -> ErrorPresentation { // 카메라 화면에서 생길 수 있는 모든 오류의 입구
        if let error = error as? CameraCaptureServiceError {
            return cameraPresentation(for: error)
        }
        
        if error is MediaDraftRepositoryError {
            return ErrorPresentation(message: "방금 촬영한 영상을 저장하지 못했어요. 다시 촬영해 주세요.", recoveryAction: .none)
        }
        
        return ErrorPresentation(message: "카메라를 준비하지 못했어요. 잠시 후 다시 시도해 주세요.", recoveryAction: .retry)
    }
    
    private static func cameraPresentation(for error: CameraCaptureServiceError) -> ErrorPresentation { // 카메라 Service에서 온 오류가 맞다고 확인한 뒤 호출
        switch error {
        case .cameraPermissionDenied:
            return ErrorPresentation(
                message: "카메라 접근 권한이 필요해요.",
                recoveryAction: .none
            )
            
        case .cameraUnavailable:
            return ErrorPresentation(
                message: "사용 가능한 카메라를 찾지 못했어요.",
                recoveryAction: .none
            )
            
        case .sessionNotConfigured:
            return ErrorPresentation(
                message: "카메라를 준비하지 못했어요. 다시 시도해 주세요.",
                recoveryAction: .retry
            )
            
        case .recordingAlreadyInProgress:
            return ErrorPresentation(
                message: "이미 녹화 중이에요.",
                recoveryAction: .none
            )
            
        case .noActiveRecording:
            return ErrorPresentation(
                message: "녹화 중인 영상이 없어요.",
                recoveryAction: .none
            )
            
        case .recordingFailed:
            return ErrorPresentation(
                message: "영상 녹화에 실패했어요. 다시 시도해 주세요.",
                recoveryAction: .retry
            )
            
        case .torchUnavailable:
            return ErrorPresentation(
                message: "현재 카메라에서는 플래시를 사용할 수 없어요.",
                recoveryAction: .none
            )
        }
    }
}
