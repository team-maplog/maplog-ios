//
//  LogPublishingAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
//

import Foundation

protocol LogPublishingAPIService {
    func uploadLogVideo( // 완성된 .mov 파일을 서버 파일 저장소에 업로드하고 fileId를 받음
        fileURL: URL
    ) async throws -> LogVideoUploadResponseDTO

    func createLog( // 받은 fileId와 캡션·대표 주소·클립 위치 정보를 서버에 보내 로그를 발행함
        request: LogCreateRequestDTO
    ) async throws -> LogCreateResponseDTO
}
