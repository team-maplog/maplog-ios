//
//  CameraPreviewView.swift
//  Maplog
//
//  Created by 한채림 on 7/31/26.
// AVCaptureSession을 바로 그리는 기본 View가 없어서, UIViewRepresentable로 UIKit의 AVCaptureVideoPreviewLayer를 감싸야함, 카메라 영상을 화면에 렌더링하는 UI 어댑터

//AVCameraCaptureService
//  → AVCaptureSession 생성·관리
//  → CameraCaptureViewModel.previewSession
//  → CameraPreviewView
//  → 실제 카메라 영상 표시

import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        
        view.previewLayer.session = session // ViewModel이 가진 previewSession을 화면 레이어에 연결하는 코드
        view.previewLayer.videoGravity = .resizeAspectFill // 이미지를 화면 전체에 꽉 채우는 방식
        view.isUserInteractionEnabled = false // 이 미리보기 자체가 터치를 먹지 않게 하는 설정
        
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        guard uiView.previewLayer.session !== session else {
            return
        }
        
        uiView.previewLayer.session = session
    }
    
    final class PreviewView: UIView { // 기본 그림 레이어를 일반 레이어 대신 카메라 영상 전용 레이어로 바꿈
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
