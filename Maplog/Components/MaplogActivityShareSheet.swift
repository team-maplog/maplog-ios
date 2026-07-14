import LinkPresentation
import SwiftUI
import UIKit

struct MaplogActivityShareSheet: UIViewControllerRepresentable {
    let post: VlogPost
    var onDismiss: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [MaplogVlogShareItem(post: post)],
            applicationActivities: nil
        )
        controller.overrideUserInterfaceStyle = .light
        controller.completionWithItemsHandler = { _, _, _, _ in
            context.coordinator.dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    final class Coordinator {
        private let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func dismiss() {
            DispatchQueue.main.async {
                self.onDismiss()
            }
        }
    }
}

private final class MaplogVlogShareItem: NSObject, UIActivityItemSource {
    private let post: VlogPost
    private let shareURL: URL

    init(post: VlogPost) {
        self.post = post
        self.shareURL = URL(string: "https://maplog.app/reels/\(post.id)")!
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        shareURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        "\(post.title)\n\(post.place.name)\n\(shareURL.absoluteString)"
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        post.title
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = post.title
        metadata.originalURL = shareURL
        metadata.url = shareURL

        if let image = UIImage(named: previewImageName) {
            metadata.imageProvider = NSItemProvider(object: image)
        }

        return metadata
    }

    private var previewImageName: String {
        switch post.id {
        case "post-1":
            return "log_seongsu_evening"
        case "post-2":
            return "log_jeju_sunrise"
        case "search-busan-night-route":
            return "log_busan_night"
        default:
            return post.imageStyle.assetName
        }
    }
}
