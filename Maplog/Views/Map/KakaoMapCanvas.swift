import SwiftUI
import UIKit
import KakaoMapsSDK

struct KakaoMapCanvas: View {
    let latitude: Double
    let longitude: Double

    @State private var shouldDrawMap = true

    var body: some View {
        Group {
            if KakaoMapSDKConfiguration.hasUsableNativeAppKey {
                KakaoMapRepresentable(
                    shouldDrawMap: $shouldDrawMap,
                    latitude: latitude,
                    longitude: longitude
                )
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
    let latitude: Double
    let longitude: Double

    // 실제 KMViewContainer 생성, Coordinator에 연결하고, 엔진 준비 시작하고 swiftUI에 반환
    func makeUIView(context: Context) -> KMViewContainer {
        let view = KMViewContainer()
        view.sizeToFit()
        // 관광 상세 지도는 기기 다크 모드와 관계없이 라이트 지도를 사용함.
        view.overrideUserInterfaceStyle = .light
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
        Coordinator(
            latitude: latitude,
            longitude: longitude)
    }


//    LabelLayer  = 핀들을 담는 폴더
//    PoiStyle    = 핀의 그림/모양
//    POI         = 특정 좌표에 실제로 놓는 핀
    final class Coordinator: NSObject, MapControllerDelegate {
        private let mapViewName = "mapview"
        private var needsInitialCameraMove = true

        private let initialPosition: MapPoint

        private let tourismPinLayerID = "tourism-pin-layer"
        private let tourismPinStyleID = "tourism-pin-style"
        private var hasAddedTourismPin = false

        init(latitude: Double, longitude: Double) {
            initialPosition = MapPoint(longitude: longitude, latitude: latitude) // initialPosition은 이번 지도 화면이 처음 열릴 때 보여줄 관광지 위치
            super.init()
        }



        var controller: KMController?
        private weak var viewContainer: KMViewContainer? // 뷰를 기억할 프로퍼티

        func createController(with view: KMViewContainer) {
            viewContainer = view
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

            let mapviewInfo = MapviewInfo(
                viewName: mapViewName,
                viewInfoName: "map",
                defaultPosition: initialPosition,
                defaultLevel: 15
            )

            controller?.addView(mapviewInfo)
        }

        private func applyMapLayoutIfReady(_ size: CGSize) { // 지도 크기와 최초 카메라 위치를 한 번에 적용하는 함수
            guard size.width > 0,
                      size.height > 0,
                  let mapView = controller?.getView(mapViewName) as? KakaoMap
            else {
                return
            }

            mapView.viewRect = CGRect(origin: .zero, size: size)

            guard needsInitialCameraMove else {
                return
            }

            let cameraUpdate = CameraUpdate.make(
                target: initialPosition,
                zoomLevel: 15,
                mapView: mapView
            )

            mapView.moveCamera(cameraUpdate)
            needsInitialCameraMove = false
        }


        @objc func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            guard let size = viewContainer?.bounds.size else {
                return
            }
            applyMapLayoutIfReady(size)
            addTourismPinIfNeeded()
        }

        private func addTourismPinIfNeeded() {
            guard !hasAddedTourismPin,
                  let mapView = controller?.getView(mapViewName) as? KakaoMap
            else {
                return
            }

            let labelManager = mapView.getLabelManager()

            let pinImage = makeTourismPinImage()

            let iconStyle = PoiIconStyle(symbol: pinImage, anchorPoint: CGPoint(x: 0.5,  y: 1.0)) // 가운데 아래쪽이 실제 관광지 좌표를 가리키게 함. 그래서 핀 끝이 위치를 정확히 찍음

            let poiStyle = PoiStyle(styleID: tourismPinStyleID, styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)])

            labelManager.addPoiStyle(poiStyle)

            let layerOption = LabelLayerOptions(
                layerID: tourismPinLayerID,
                competitionType: .none,
                competitionUnit: .symbolFirst,
                orderType: .rank,
                zOrder: 1
            )

            guard let layer = labelManager.addLabelLayer(option: layerOption) else {
                return
            }

            let poiOption = PoiOptions(styleID: tourismPinStyleID, poiID: "tourism-location")

            let pin = layer.addPoi(option: poiOption, at: initialPosition)

            pin?.show()
            hasAddedTourismPin = true
        }

        private func makeTourismPinImage() -> UIImage? {
            guard let sourceImage = UIImage(named: "MaplogPinGlyph") else {
                return nil
            }

            let size = CGSize(width: 42, height: 42)
            let tintedImage = sourceImage.withTintColor(
                UIColor(Color.maplogPrimary),
                renderingMode: .alwaysOriginal
            )
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { _ in
                tintedImage.draw(
                    in: CGRect(origin: .zero, size: size)
                )
            }
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
            applyMapLayoutIfReady(size)


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
