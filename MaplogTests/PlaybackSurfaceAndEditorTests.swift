import AVFoundation
import Combine
import SwiftUI
import XCTest
@testable import Maplog

@MainActor
final class PlaybackSurfaceAndEditorTests: XCTestCase {
    func testRemovedPlaybackSurfaceDisconnectsAndReconnectsWhenVisible() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 500)
        let player = AVPlayer()
        let host = UIHostingController(rootView: MaplogVideoPlayerLayerView(player: player, videoGravity: .resizeAspectFill))
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        let surface = try XCTUnwrap(find(MaplogPlayerLayerContainerView.self, in: host.view))
        XCTAssertTrue(surface.playerLayer.player === player)
        window.rootViewController = nil
        XCTAssertNil(surface.playerLayer.player, "사라진 화면이 같은 플레이어의 영상 출력을 계속 잡으면 안 됩니다.")
        window.rootViewController = host
        host.view.layoutIfNeeded()
        XCTAssertTrue(surface.playerLayer.player === player)
    }

    func testEditorKeepsKeyboardAfterNativeFocusAndSwiftUIUpdate() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 500)
        let state = EditorState()
        let host = UIHostingController(rootView: EditorHarness(state: state))
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        let editor = try XCTUnwrap(find(UITextView.self, in: host.view))
        XCTAssertTrue(editor.becomeFirstResponder())
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(editor.isFirstResponder)
        XCTAssertTrue(state.focused)
        editor.insertText("여행 #한강")
        state.revision += 1
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(editor.isFirstResponder)
        XCTAssertEqual(state.text, "여행 #한강")
        state.focused = false
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(editor.isFirstResponder)
    }

    private func find<T: UIView>(_ type: T.Type, in root: UIView) -> T? {
        if let found = root as? T { return found }
        for view in root.subviews {
            if let found = find(type, in: view) { return found }
        }
        return nil
    }
}

@MainActor
private final class EditorState: ObservableObject {
    @Published var text = ""
    @Published var focused = false
    @Published var revision = 0
}

private struct EditorHarness: View {
    @ObservedObject var state: EditorState
    var body: some View {
        VStack {
            Text("\(state.revision)")
            LogHashtagTextEditor(text: $state.text, isFocused: $state.focused)
                .frame(height: 148)
        }
    }
}
