//
//  AVVideoThumbnailService.swift
//  Maplog
//
//  Created by 한채림 on 8/1/26.
//

import AVFoundation
import Foundation
import UIKit

actor AVVideoThumbnailService: VideoThumbnailService {
    func makeThumbnailData(for videoURL: URL) async throws -> Data {
        let asset = AVURLAsset(url: videoURL) // 저장된 .mov 영상 파일을 AVFoundation이 읽을 수 있는 영상 자산으로 바꿈
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        imageGenerator.appliesPreferredTrackTransform = true  // 세로로 촬영한 영상이 가로로 누워 보이지 않도록, 카메라의 회전 정보를 적용
        imageGenerator.maximumSize = CGSize(width: 320, height: 320) // 작은 카메라 버튼에 쓸 썸네일이므로 원본 해상도 전체를 만들지 않고, 최대 320px 크기까지만 만들어요. 메모리와 생성 시간을 줄이는 설정
        
        let result = try await imageGenerator.image(at: .zero) // 영상의 0초 지점, 즉 첫 프레임을 추출함
        
        let image = UIImage(cgImage: result.image) // 꺼낸 프레임을 JPEG Data로 바꿔 ViewModel에 전달할 수 있게 함
        
        guard let data = image.jpegData(compressionQuality: 0.78) else {
            throw VideoThumbnailServiceError.imageEncodingFailed
        }
        
        return data
    }
}
