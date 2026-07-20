import SwiftUI

@main
struct MaplogApp: App {
    @StateObject private var authSessionStore = AuthSessionStore()
    
    init() {
        KakaoMapSDKConfiguration.initializeIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authSessionStore) 
        }
    }
}
