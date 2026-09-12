//
//  AVCameraCaptureService.swift
//  Maplog
//
//  Created by 한채림 on 7/31/26.
//

import AVFoundation
import Foundation

final class AVCameraCaptureService: NSObject, CameraCaptureService {
    let previewSession = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "com.maplog.camera.session")
    
    private let movieOutput = AVCaptureMovieFileOutput()
    private let fileManager: FileManager
    
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var currentVideoDevice: AVCaptureDevice?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    
    private var storedPosition: CameraPosition = .rear
    private var recordingStartDate: Date?
    private var recordingContinuation: CheckedContinuation<CameraRecordedVideo, Error>?
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        super.init()
    }
    
    var currentPosition: CameraPosition {
        sessionQueue.sync { // Queue에서 값을 읽어 올 때까지 잠깐 기다렸다가 반환, currentPosition을 안전하게 읽기 위해 사용
            storedPosition
        }
    }
    
    func cameraAuthorizationStatus() -> CaptureAuthorizationStatus {
        makeAuthorizationStatus(from: AVCaptureDevice.authorizationStatus(for: .video))
    }
    
    func requestCameraAuthorization() async -> CaptureAuthorizationStatus {
        guard cameraAuthorizationStatus() == .notDetermined else {
            return cameraAuthorizationStatus()
        }
        
        let isGranted = await AVCaptureDevice.requestAccess(for: .video)
        
        return isGranted ? .authorized : cameraAuthorizationStatus()
    }
    
    func microphoneAuthorizationStatus() -> CaptureAuthorizationStatus {
        makeAuthorizationStatus(from: AVCaptureDevice.authorizationStatus(for: .audio))
    }
    
    func requestMicrophoneAuthorization() async -> CaptureAuthorizationStatus {
        guard microphoneAuthorizationStatus() == .notDetermined else {
            return microphoneAuthorizationStatus()
        }
        
        let isGranted = await AVCaptureDevice.requestAccess(for: .audio)
        
        return isGranted
        ? .authorized
        : microphoneAuthorizationStatus()
    }
    
    // 후면 카메라를 연결하고 녹화 출력 준비
    func configureSession(position: CameraPosition) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CameraCaptureServiceError.cameraUnavailable)
                    return
                }
                do {
                    try configureSessionOnQueue(position: position)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // 실제 카메라 미리보기 시작
    func startSession() async {
        await withCheckedContinuation {
            (continuation: CheckedContinuation<Void, Never>) in
            
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                
                if !previewSession.isRunning {
                    previewSession.startRunning()
                }
                
                continuation.resume()
            }
        }
    }
    
    func stopSession() async {
        await withCheckedContinuation {
            (continuation: CheckedContinuation<Void, Never>) in
            
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                
                if movieOutput.isRecording {
                    movieOutput.stopRecording()
                }
                
                if previewSession.isRunning {
                    previewSession.stopRunning()
                }
                
                continuation.resume()
            }
        }
    }
    
    func switchCamera() async throws -> CameraPosition {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<CameraPosition, Error>) in
            
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(
                        throwing: CameraCaptureServiceError.cameraUnavailable
                    )
                    return
                }
                
                guard !movieOutput.isRecording else {
                    continuation.resume(
                        throwing: CameraCaptureServiceError.recordingAlreadyInProgress
                    )
                    return
                }
                
                let nextPosition: CameraPosition = storedPosition == .rear
                ? .front
                : .rear
                
                do {
                    try configureSessionOnQueue(position: nextPosition)
                    continuation.resume(returning: nextPosition)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    func isTorchAvailable() async -> Bool {
        await withCheckedContinuation {
            (continuation: CheckedContinuation<Bool, Never>) in
            
            sessionQueue.async { [weak self] in
                continuation.resume(
                    returning: self?.currentVideoDevice?.hasTorch ?? false
                )
            }
        }
    }
    func setTorchEnabled(
        _ isEnabled: Bool
    ) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            
            sessionQueue.async { [weak self] in
                guard
                    let self,
                    let device = currentVideoDevice,
                    device.hasTorch
                else {
                    continuation.resume(
                        throwing: CameraCaptureServiceError.torchUnavailable
                    )
                    return
                }
                
                do {
                    try device.lockForConfiguration()
                    device.torchMode = isEnabled ? .on : .off
                    device.unlockForConfiguration()
                    
                    continuation.resume()
                } catch {
                    continuation.resume(
                        throwing: CameraCaptureServiceError.torchUnavailable
                    )
                }
            }
        }
    }
    
    func startRecording() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(
                        throwing: CameraCaptureServiceError.cameraUnavailable
                    )
                    return
                }
                
                guard previewSession.isRunning else {
                    continuation.resume(
                        throwing: CameraCaptureServiceError.sessionNotConfigured
                    )
                    return
                }
                
                guard movieOutput.connection(with: .video) != nil else {
                    continuation.resume(
                        throwing: CameraCaptureServiceError.sessionNotConfigured
                    )
                    return
                }
                
                guard !movieOutput.isRecording else {
                    continuation.resume(
                        throwing: CameraCaptureServiceError.recordingAlreadyInProgress
                    )
                    return
                }
                
                let outputURL = fileManager.temporaryDirectory
                    .appendingPathComponent(
                        "maplog-\(UUID().uuidString).mov"
                    )
                
                if fileManager.fileExists(atPath: outputURL.path) {
                    try? fileManager.removeItem(at: outputURL)
                }
                
                recordingStartDate = Date()

                if let videoConnection = movieOutput.connection(
                    with: .video
                ) {
                    let rotationAngle = rotationCoordinator?
                        .videoRotationAngleForHorizonLevelCapture ?? 0

                    if videoConnection.isVideoRotationAngleSupported(
                        rotationAngle
                    ) {
                        videoConnection.videoRotationAngle = rotationAngle
                    }
                }

                movieOutput.startRecording(
                    to: outputURL,
                    recordingDelegate: self
                )
                
                continuation.resume()
            }
        }
    }
    
    func stopRecording() async throws
    -> CameraRecordedVideo {
        try await withCheckedThrowingContinuation {
            (
                continuation:
                    CheckedContinuation<CameraRecordedVideo, Error>
            ) in
            
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(
                        throwing: CameraCaptureServiceError.cameraUnavailable
                    )
                    return
                }
                
                guard movieOutput.isRecording else {
                    continuation.resume(
                        throwing: CameraCaptureServiceError.noActiveRecording
                    )
                    return
                }
                
                guard recordingContinuation == nil else {
                    continuation.resume(
                        throwing: CameraCaptureServiceError.recordingAlreadyInProgress
                    )
                    return
                }
                
                recordingContinuation = continuation
                movieOutput.stopRecording()
            }
        }
    }
    
    private func configureSessionOnQueue(
        position: CameraPosition
    ) throws {
        guard cameraAuthorizationStatus() == .authorized else {
            throw CameraCaptureServiceError.cameraPermissionDenied
        }
        
        previewSession.beginConfiguration()
        defer {
            previewSession.commitConfiguration()
        }
        
        if previewSession.canSetSessionPreset(.high) {
            previewSession.sessionPreset = .high
        }
        
        if let videoInput {
            previewSession.removeInput(videoInput)
        }
        
        if let audioInput {
            previewSession.removeInput(audioInput)
        }
        
        let avPosition: AVCaptureDevice.Position = position == .rear
        ? .back
        : .front
        
        guard let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: avPosition
        ) else {
            throw CameraCaptureServiceError.cameraUnavailable
        }
        
        let newVideoInput = try AVCaptureDeviceInput(
            device: videoDevice
        )
        
        guard previewSession.canAddInput(newVideoInput) else {
            throw CameraCaptureServiceError.cameraUnavailable
        }
        
        previewSession.addInput(newVideoInput)
        videoInput = newVideoInput
        currentVideoDevice = videoDevice
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(
            device: videoDevice,
            previewLayer: nil
        )
        storedPosition = position
        
        let microphoneIsAuthorized =
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        
        if microphoneIsAuthorized,
           let audioDevice = AVCaptureDevice.default(for: .audio) {
            let newAudioInput = try AVCaptureDeviceInput(
                device: audioDevice
            )
            
            if previewSession.canAddInput(newAudioInput) {
                previewSession.addInput(newAudioInput)
                audioInput = newAudioInput
            }
        }
        
        let hasMovieOutput = previewSession.outputs.contains {
            $0 === movieOutput
        }
        
        if !hasMovieOutput,
           previewSession.canAddOutput(movieOutput) {
            previewSession.addOutput(movieOutput)
        }
    }
    
    private func makeAuthorizationStatus(
        from status: AVAuthorizationStatus
    ) -> CaptureAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

}

extension AVCameraCaptureService:
    AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            let continuation = recordingContinuation
            recordingContinuation = nil

            let duration = max(
                0,
                Date().timeIntervalSince(recordingStartDate ?? Date())
            )
            recordingStartDate = nil

            guard let continuation else {
                try? fileManager.removeItem(at: outputFileURL)
                return
            }

            guard error == nil else {
                try? fileManager.removeItem(at: outputFileURL)

                continuation.resume(
                    throwing: CameraCaptureServiceError.recordingFailed
                )
                return
            }

            continuation.resume(
                returning: CameraRecordedVideo(
                    temporaryFileURL: outputFileURL,
                    duration: duration
                )
            )
        }
    }
}
