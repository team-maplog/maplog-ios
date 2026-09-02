//
//  LogPublishAttempt.swift
//  Maplog
//
//  로그 발행 한 번을 식별하는 재시도 정보
//

import Foundation

/// 동일 초안의 결과가 불명확할 때 서버에 같은 발행 요청임을 알리는 값입니다.
/// 화면을 새로 열거나 초안이 바뀌면 새 시도가 만들어집니다.
struct LogPublishAttempt: Equatable, Sendable {
    let draft: LogPublishDraft
    let idempotencyKey: String

    init(
        draft: LogPublishDraft,
        idempotencyKey: UUID = UUID()
    ) {
        self.draft = draft
        self.idempotencyKey = idempotencyKey.uuidString
    }

    func isForSameDraft(
        _ draft: LogPublishDraft
    ) -> Bool {
        self.draft == draft
    }
}
