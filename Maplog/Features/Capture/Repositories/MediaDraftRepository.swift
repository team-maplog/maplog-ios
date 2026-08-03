//
//  MediaDraftRepository.swift
//  Maplog
//
//  Created by 한채림 on 7/30/26.
//

import Foundation

protocol MediaDraftRepository: Sendable { // Sendable은 카메라 저장처럼 비동기 작업을 할 때, Repository를 안전하게 다른 작업 흐름으로 전달할 수 있다는 표시
    func saveDraft(from input: CaptureDraftClipInput) async throws -> CaptureDraftClip // 임시 영상 파일을 앱 내부에 저장하고, 저장 결과 모델을 반환
    
    func fetchDrafts() async throws -> [CaptureDraftClip] // 나중의 편집 화면에서 선택할 저장 클립 목록 조회
    
    func deleteDraft(id: UUID) async throws // 편집 화면에서 버린 클립의 파일과 메타데이터 제거
}
