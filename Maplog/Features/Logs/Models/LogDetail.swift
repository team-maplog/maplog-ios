import Foundation

/// 발행된 로그 한 건을 상세 화면에 표시하기 위한 앱 내부 모델입니다.
/// 작성자와 클립 모델은 릴스와 서버 계약이 같으므로 기존 타입을 재사용합니다.
struct LogDetail: Equatable, Sendable {
    let id: Int64
    let author: LogReelAuthor
    let caption: String
    let address: String
    let thumbnailURL: URL?
    let playbackURL: URL?
    let publishedAt: Date
    let viewCount: Int64
    let clips: [LogReelClip]
    let likeCount: Int64
    let commentCount: Int64
    let isLikedByViewer: Bool
    let isSavedByViewer: Bool

    func replacingCaption(
        with caption: String
    ) -> LogDetail {
        LogDetail(
            id: id,
            author: author,
            caption: caption,
            address: address,
            thumbnailURL: thumbnailURL,
            playbackURL: playbackURL,
            publishedAt: publishedAt,
            viewCount: viewCount,
            clips: clips,
            likeCount: likeCount,
            commentCount: commentCount,
            isLikedByViewer: isLikedByViewer,
            isSavedByViewer: isSavedByViewer
        )
    }
}

/// 캡션 수정 API가 돌려준 결과 중 화면 상태 갱신에 필요한 값만 표현합니다.
struct LogCaptionUpdateResult: Equatable, Sendable {
    let caption: String
}
