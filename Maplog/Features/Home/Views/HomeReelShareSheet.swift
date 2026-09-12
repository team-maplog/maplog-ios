import SwiftUI
import UIKit

/// 서버에 공유 endpoint가 없으므로, 현재 로그의 실제 문구와 장소를 iOS 시스템 공유 시트에 전달합니다.
/// 공개 웹 링크가 확정되면 이 타입에 URL만 추가하면 됩니다.
struct HomeReelShareSheet: UIViewControllerRepresentable {
    let reel: HomeReelViewData

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        controller.overrideUserInterfaceStyle = .light
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}

    private var shareText: String {
        let caption = reel.caption.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let body = caption.isEmpty ? "Maplog에서 발견한 장소" : caption

        return "\(body)\n📍 \(reel.address)\nMaplog · @\(reel.authorName)"
    }
}
