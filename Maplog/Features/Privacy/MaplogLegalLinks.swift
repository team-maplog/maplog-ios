import SwiftUI

/// 랜딩페이지도 같은 공개 문서를 연결한다. 로그인 없이 열 수 있어야 한다.
enum MaplogLegalLinks {
    static let terms = URL(string: "https://api-maplog.millenniumrhino.com/terms")!
    static let privacy = URL(string: "https://api-maplog.millenniumrhino.com/privacy")!
    static let support = URL(string: "mailto:millenniumrhino@gmail.com")!
}
