import Foundation

/// 홈에서는 실제 포스터 여부 대신 세로형 원본이라는 표시 기준을 사용한다.
struct TourismPortraitImage: Equatable {
    let url: URL
    let data: Data
    let width: Int
    let height: Int

    init?(url: URL, data: Data, width: Int, height: Int) {
        guard width > 0, height > width, !data.isEmpty else { return nil }
        self.url = url
        self.data = data
        self.width = width
        self.height = height
    }

    var aspectRatio: Double { Double(width) / Double(height) }
}
