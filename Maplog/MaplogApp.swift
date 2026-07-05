import SwiftUI

@main
struct MaplogApp: App {
    init() {
        KakaoMapSDKConfiguration.initializeIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
