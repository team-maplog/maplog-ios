import SwiftUI
import KakaoMapsSDK

struct KakaoMapCanvas: View {
    @State private var shouldDrawMap = true

    var body: some View {
        Group {
            if KakaoMapSDKConfiguration.hasUsableNativeAppKey {
                KakaoMapRepresentable(shouldDrawMap: $shouldDrawMap)
                    .onAppear {
                        KakaoMapSDKConfiguration.initializeIfNeeded()
                        shouldDrawMap = true
                    }
                    .onDisappear {
                        shouldDrawMap = false
                    }
            } else {
                KakaoMapSetupPlaceholder()
            }
        }
    }
}

private struct KakaoMapRepresentable: UIViewRepresentable {
    @Binding var shouldDrawMap: Bool

    // 실제 KMViewContainer 생성, Coordinator에 연결하고, 엔진 준비 시작하고 swiftUI에 반환
    func makeUIView(context: Context) -> KMViewContainer {
        let view = KMViewContainer()
        view.sizeToFit()
        context.coordinator.createController(with: view)
        context.coordinator.prepareEngineIfNeeded()
        return view
    }

    // swiftUI 상태가 바뀔 때 호출, 엔진 활성화, 렌더링 멈춤
    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        if shouldDrawMap {
            context.coordinator.activateEngineIfNeeded()
        } else {
            context.coordinator.controller?.pauseEngine()
        }
    }

    // swiftUI가 UIKit View를 완전히 제거할 때 호출, pauseEngine()후 resetEngine()으로 SDK 리소스 정리
    static func dismantleUIView(_ uiView: KMViewContainer, coordinator: Coordinator) {
        coordinator.controller?.pauseEngine()
        coordinator.controller?.resetEngine()
    }

    // swiftUI가 보관할 Coordinator 객체 생성
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MapControllerDelegate {
        private let mapViewName = "mapview"
        private var needsInitialCameraMove = true

        var controller: KMController?

        func createController(with view: KMViewContainer) {
            controller = KMController(viewContainer: view)
            controller?.delegate = self
        }

        func markNeedsInitialCameraMove() {
            needsInitialCameraMove = true
        }

        func prepareEngineIfNeeded() {
            guard controller?.isEnginePrepared == false else {
                return
            }

            controller?.prepareEngine()
        }

        func activateEngineIfNeeded() {
            prepareEngineIfNeeded()

            guard controller?.isEngineActive == false else {
                return
            }

            controller?.activateEngine()
        }

        @objc func addViews() {
            let defaultPosition = MapPoint(longitude: 126.9780, latitude: 37.5665)
            let mapviewInfo = MapviewInfo(
                viewName: mapViewName,
                viewInfoName: "map",
                defaultPosition: defaultPosition,
                defaultLevel: 10
            )

            controller?.addView(mapviewInfo)
        }

        @objc func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            print("Kakao map loaded: \(viewName), \(viewInfoName)")
        }

        @objc func addViewFailed(_ viewName: String, viewInfoName: String) {
            print("Kakao map failed to load: \(viewName), \(viewInfoName)")
        }

        @objc func authenticationFailed(_ errorCode: Int, desc: String) {
            print("Kakao map authentication failed: \(errorCode), \(desc)")
        }

        @objc func authenticationSucceeded() {
            print("Kakao map authentication succeeded")
        }

        @objc func containerDidResized(_ size: CGSize) {
            guard let mapView = controller?.getView(mapViewName) as? KakaoMap else {
                return
            }

            mapView.viewRect = CGRect(origin: .zero, size: size)

            guard needsInitialCameraMove else {
                return
            }

            let cameraUpdate = CameraUpdate.make(
                target: MapPoint(longitude: 126.9780, latitude: 37.5665),
                zoomLevel: 10,
                mapView: mapView
            )
            mapView.moveCamera(cameraUpdate)
            needsInitialCameraMove = false
        }
    }
}

private struct KakaoMapSetupPlaceholder: View {
    var body: some View {
        ZStack {
            Color(red: 0.86, green: 0.92, blue: 0.88)

            VStack(spacing: MaplogSpacing.small) {
                Image(systemName: "map")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(Color.maplogInk)

                Text("카카오 지도 앱 키가 필요해요")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.maplogInk)

                Text("Config/Secrets.xcconfig에 네이티브 앱 키를 넣으면 지도가 표시됩니다.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.maplogMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 160)
        }
    }
}
