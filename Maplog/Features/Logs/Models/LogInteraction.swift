import Foundation

/// 좋아요와 저장 API가 돌려주는, 현재 사용자의 상태 변경 결과입니다.
///
/// 화면은 서버의 boolean을 그대로 상태로 사용합니다. 버튼을 여러 번 눌러도
/// 임의로 +1/-1 하지 않도록, 좋아요 수는 ViewModel에서 이전 상태와 이 값을 비교해 갱신합니다.
struct LogLikeInteractionResult: Equatable, Sendable {
    let logID: Int64
    let isLiked: Bool
}

struct LogSaveInteractionResult: Equatable, Sendable {
    let logID: Int64
    let isSaved: Bool
}
