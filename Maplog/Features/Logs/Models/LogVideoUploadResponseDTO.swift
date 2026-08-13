//
//  LogVideoUploadResponseDTO.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// 영상 업로드 응답 DTO, 영상 업로드 API의 data.fileId를 받는 모델

import Foundation

struct LogVideoUploadResponseDTO: Decodable {
    let fileId: Int64
}
