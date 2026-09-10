import Foundation

/// 검수한 포스터의 식별 정보. 같은 축제 ID의 다른 연도 행사에 재사용하지 않는다.
struct VerifiedTourismPoster {
    let tourismID: Int64
    let imageURL: URL
    let eventStartDate: String // yyyy-MM-dd, Asia/Seoul
    let eventEndDate: String
}

protocol VerifiedTourismPosterProviding {
    var tourismIDs: Set<Int64> { get }
    func posterURL(tourismID: Int64, startDate: Date?, endDate: Date?) -> URL?
}

/// 서버에 검수 정보가 제공되기 전 사용하는 명시적인 등록 목록이다.
/// 이미지 모양이나 이름으로 포스터 여부를 추측하지 않는다.
struct LocalVerifiedTourismPosterCatalog: VerifiedTourismPosterProviding {
    let posters: [VerifiedTourismPoster]

    var tourismIDs: Set<Int64> { Set(posters.map(\.tourismID)) }

    func posterURL(tourismID: Int64, startDate: Date?, endDate: Date?) -> URL? {
        guard let startDate, let endDate else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        let matches = posters.filter {
            $0.tourismID == tourismID
                && $0.eventStartDate == formatter.string(from: startDate)
                && $0.eventEndDate == formatter.string(from: endDate)
                && ["https", "http"].contains($0.imageURL.scheme?.lowercased() ?? "")
                && $0.imageURL.host != nil
        }
        // 같은 행사에 서로 다른 포스터가 중복 등록되어도 임의로 선택하지 않는다.
        guard matches.count == 1 else { return nil }
        return matches.first?.imageURL
    }
}

/// 실제 원본을 확인한 항목만 추가한다. 샘플이나 미확인 URL을 운영 목록에 넣지 않는다.
enum VerifiedTourismPosters {
    static let entries: [VerifiedTourismPoster] = []
}
