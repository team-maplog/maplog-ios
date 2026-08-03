//
//  CameraCaptureService.swift
//  Maplog
//
//  Created by 한채림 on 7/31/26.
//

import AVFoundation

protocol CameraCaptureService: AnyObject { // AnyObject는 카메라 Service가 복사되면 안 되는 참조 타입이라는 표시, 카메라 세션 하나를 계속 같은 객체가 관리
    var previewSession: AVCaptureSession { get } // 실제 카메라 화면은 AVCaptureSession을 UIViewRepresentable의 미리보기 레이어에 연결해야 보임, 카메라를 조작하는 로직이 아니라 화면에 영상을 그리기 위한 연결 고리로만 View에 전달
    
    var currentPosition: CameraPosition { get }
    
    func cameraAuthorizationStatus() -> CaptureAuthorizationStatus
    
    func requestCameraAuthorization() async -> CaptureAuthorizationStatus
    
    func microphoneAuthorizationStatus() -> CaptureAuthorizationStatus
    
    func requestMicrophoneAuthorization() async -> CaptureAuthorizationStatus
    
    func configureSession(position: CameraPosition) async throws
    
    func startSession() async
    
    func stopSession() async
    
    func switchCamera() async throws -> CameraPosition
    
    func isTorchAvailable() async -> Bool
    
    func setTorchEnabled(_ isEnabled: Bool) async throws
    
    func startRecording() async throws
    
    func stopRecording() async throws -> CameraRecordedVideo
}
