import SwiftUI
import UIKit
import KakaoMapsSDK

/// 관광 상세 화면에서 하나의 관광지 위치를 표시하는 카카오 지도 캔버스입니다.
struct TourismKakaoMapCanvas: View {
    let latitude: Double
    let longitude: Double

    @State private var shouldDrawMap = true

    var body: some View {
        Group {
            if KakaoMapSDKConfiguration.hasUsableNativeAppKey {
                TourismKakaoMapRepresentable(
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
                TourismKakaoMapSetupPlaceholder()
            }
        }
    }
}

private struct TourismKakaoMapRepresentable: UIViewRepresentable {
    @Binding var shouldDrawMap: Bool
    let latitude: Double
    let longitude: Double

    func makeUIView(context: Context) -> KMViewContainer {
        let view = KMViewContainer()
        view.sizeToFit()
        view.overrideUserInterfaceStyle = .light
        context.coordinator.createController(with: view)
        context.coordinator.prepareEngineIfNeeded()
        return view
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        if shouldDrawMap {
            context.coordinator.activateEngineIfNeeded()
        } else {
            context.coordinator.controller?.pauseEngine()
        }
    }

    static func dismantleUIView(_ uiView: KMViewContainer, coordinator: Coordinator) {
        coordinator.controller?.pauseEngine()
        coordinator.controller?.resetEngine()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(latitude: latitude, longitude: longitude)
    }

    final class Coordinator: NSObject, MapControllerDelegate {
        private let mapViewName = "tourism-map-view"
        private let tourismPinLayerID = "tourism-pin-layer"
        private let tourismPinStyleID = "tourism-pin-style"
        private let initialPosition: MapPoint

        private var needsInitialCameraMove = true
        private var hasAddedTourismPin = false
        private weak var viewContainer: KMViewContainer?

        var controller: KMController?

        init(latitude: Double, longitude: Double) {
            initialPosition = MapPoint(longitude: longitude, latitude: latitude)
            super.init()
        }

        func createController(with view: KMViewContainer) {
            viewContainer = view
            controller = KMController(viewContainer: view)
            controller?.delegate = self
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
            let mapViewInfo = MapviewInfo(
                viewName: mapViewName,
                viewInfoName: "map",
                defaultPosition: initialPosition,
                defaultLevel: 15
            )
            controller?.addView(mapViewInfo)
        }

        @objc func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            guard let size = viewContainer?.bounds.size else {
                return
            }

            applyMapLayoutIfReady(size)
            addTourismPinIfNeeded()
        }

        @objc func addViewFailed(_ viewName: String, viewInfoName: String) {
            assertionFailure("Kakao map failed to load: \(viewName), \(viewInfoName)")
        }

        @objc func authenticationFailed(_ errorCode: Int, desc: String) {
            assertionFailure("Kakao map authentication failed: \(errorCode), \(desc)")
        }

        @objc func authenticationSucceeded() {}

        @objc func containerDidResized(_ size: CGSize) {
            applyMapLayoutIfReady(size)
        }

        private func applyMapLayoutIfReady(_ size: CGSize) {
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

        private func addTourismPinIfNeeded() {
            guard !hasAddedTourismPin,
                  let mapView = controller?.getView(mapViewName) as? KakaoMap
            else {
                return
            }

            let labelManager = mapView.getLabelManager()
            let iconStyle = PoiIconStyle(
                symbol: makeTourismPinImage(),
                anchorPoint: CGPoint(x: 0.5, y: 1)
            )
            let poiStyle = PoiStyle(
                styleID: tourismPinStyleID,
                styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)]
            )
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

            let pin = layer.addPoi(
                option: PoiOptions(styleID: tourismPinStyleID, poiID: "tourism-location"),
                at: initialPosition
            )
            pin?.show()
            hasAddedTourismPin = true
        }

        private func makeTourismPinImage() -> UIImage? {
            guard let sourceImage = UIImage(named: "MaplogPinGlyph") else {
                return nil
            }

            let size = CGSize(width: 28, height: 28)
            let tintedImage = sourceImage.withTintColor(
                UIColor(Color.maplogPrimary),
                renderingMode: .alwaysOriginal
            )
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                tintedImage.draw(in: CGRect(origin: .zero, size: size))
            }
        }
    }
}

private struct TourismKakaoMapSetupPlaceholder: View {
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
