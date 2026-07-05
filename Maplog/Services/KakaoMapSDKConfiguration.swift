import Foundation
import KakaoMapsSDK

enum KakaoMapSDKConfiguration {
    private static var didInitialize = false

    static var nativeAppKey: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String else {
            return ""
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var hasUsableNativeAppKey: Bool {
        !nativeAppKey.isEmpty && !nativeAppKey.contains("REPLACE_WITH")
    }

    @discardableResult
    static func initializeIfNeeded() -> Bool {
        guard hasUsableNativeAppKey else {
            return false
        }

        guard !didInitialize else {
            return true
        }

        SDKInitializer.InitSDK(appKey: nativeAppKey)
        didInitialize = true
        return true
    }
}
