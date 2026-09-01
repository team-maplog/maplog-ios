import Foundation

/// 서버가 access token을 인정했음을 표현하는 최소 도메인 모델임
struct AuthenticatedSession: Equatable {
    let userID: UUID
}
