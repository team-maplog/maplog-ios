//
//  ExploreKakaoMap.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
//

import SwiftUI
import UIKit
import KakaoMapsSDK

struct ExploreKakaoMap: View {
    let markers: [MapMarker] // 지금 지도에 그릴 전체 핀
    let selectedMarkerID: String? // 현재 선택되어 강조 표시할 핀

    let onViewportChanged: (MapViewport) -> Void
    let onMarkerSelected: (String) -> Void // 핀을 탭했을 때 ViewModel에 전달할 동작

    @State private var shouldDrawMap = true

    var body: some View {
        Group {
            if KakaoMapSDKConfiguration.hasUsableNativeAppKey {
                ExploreKakaoMapRepresentable(
                    shouldDrawMap: $shouldDrawMap,
                    markers: markers,
                    selectedMarkerID: selectedMarkerID,
                    onViewportChanged: onViewportChanged,
                    onMarkerSelected: onMarkerSelected
                )
                .onAppear {
                    KakaoMapSDKConfiguration.initializeIfNeeded()
                    shouldDrawMap = true
                }
                .onDisappear {
                    shouldDrawMap = false
                }
            } else {
                ExploreMapSetupPlaceholder()
            }
        }
    }
}

private struct ExploreKakaoMapRepresentable: UIViewRepresentable {
    @Binding var shouldDrawMap: Bool

    let markers: [MapMarker]
    let selectedMarkerID: String?

    let onViewportChanged: (MapViewport) -> Void
    let onMarkerSelected: (String) -> Void

    func makeUIView(
        context: Context
    ) -> KMViewContainer {
        let view = KMViewContainer()
        view.sizeToFit()

        context.coordinator.createController(
            with: view
        )
        context.coordinator.prepareEngineIfNeeded()

        return view
    }

    func updateUIView(
        _ uiView: KMViewContainer,
        context: Context
    ) {
        context.coordinator.updateMarkers(
            markers,
            selectedMarkerID: selectedMarkerID
        )

        if shouldDrawMap {
            context.coordinator.activateEngineIfNeeded()
        } else {
            context.coordinator.pauseEngine()
        }
    }

    static func dismantleUIView(
        _ uiView: KMViewContainer,
        coordinator: Coordinator
    ) {
        coordinator.resetEngine()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            markers: markers,
            selectedMarkerID: selectedMarkerID,
            onViewportChanged: onViewportChanged,
            onMarkerSelected: onMarkerSelected
        )
    }

    final class Coordinator: NSObject, MapControllerDelegate, KakaoMapEventDelegate {
        private let mapViewName = "explore-map"
        private let markerLayerID = "explore-map-marker-layer"

        private var markers: [MapMarker]
        private var selectedMarkerID: String?

        private let onViewportChanged: (MapViewport) -> Void
        private let onMarkerSelected: (String) -> Void

        private var needsMarkerRender = true
        private var registeredMarkerStyleIDs: Set<String> = []

        private weak var viewContainer: KMViewContainer?
        private var controller: KMController?


        init(
            markers: [MapMarker],
            selectedMarkerID: String?,
            onViewportChanged: @escaping (MapViewport) -> Void,
            onMarkerSelected: @escaping (String) -> Void
        ) {
            self.markers = markers
            self.selectedMarkerID = selectedMarkerID
            self.onViewportChanged = onViewportChanged
            self.onMarkerSelected = onMarkerSelected

            super.init()
        }

        func createController(
            with view: KMViewContainer
        ) {
            viewContainer = view

            controller = KMController(
                viewContainer: view
            )
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

        func pauseEngine() {
            controller?.pauseEngine()
        }

        func resetEngine() {
            controller?.pauseEngine()
            controller?.resetEngine()

            registeredMarkerStyleIDs.removeAll()
            needsMarkerRender = true
        }

        func updateMarkers(
            _ markers: [MapMarker],
            selectedMarkerID: String?
        ) {
            let markersChanged = self.markers != markers
            let selectionChanged =
                self.selectedMarkerID != selectedMarkerID

            self.markers = markers
            self.selectedMarkerID = selectedMarkerID

            if markersChanged || selectionChanged {
                needsMarkerRender = true
            }

            renderMarkersIfNeeded()
        }

        @objc func addViews() {
            let initialPosition = MapPoint(
                longitude: 127.0479,
                latitude: 37.5446
            )

            let mapViewInfo = MapviewInfo(
                viewName: mapViewName,
                viewInfoName: "map",
                defaultPosition: initialPosition,
                defaultLevel: 13
            )

            controller?.addView(mapViewInfo)
        }

        @objc func poiDidTapped(
            kakaoMap: KakaoMap,
            layerID: String,
            poiID: String,
            position: MapPoint
        ) {
            guard layerID == markerLayerID,
                  markers.contains(
                    where: { $0.id == poiID }
                  )
            else {
                return
            }

            onMarkerSelected(poiID)
        }

        @objc func addViewSucceeded(
            _ viewName: String,
            viewInfoName: String
        ) {
            guard viewName == mapViewName else {
                return
            }

            guard let mapView = currentMapView,
                  let size = viewContainer?.bounds.size
            else {
                return
            }

            applyMapLayout(
                mapView: mapView,
                size: size
            )

            mapView.eventDelegate = self
            mapView.poiClickable = true

            renderMarkersIfNeeded()

            notifyViewportChanged(
                from: mapView
            )
        }

        @objc func containerDidResized(
            _ size: CGSize
        ) {
            guard let mapView = currentMapView else {
                return
            }

            applyMapLayout(
                mapView: mapView,
                size: size
            )

            notifyViewportChanged(
                from: mapView
            )
        }

        @objc func addViewFailed(
            _ viewName: String,
            viewInfoName: String
        ) {
        }

        @objc func authenticationFailed(
            _ errorCode: Int,
            desc: String
        ) {
        }

        @objc func authenticationSucceeded() {
        }

        func cameraDidStopped(
            kakaoMap: KakaoMap,
            by: MoveBy
        ) {
            notifyViewportChanged(
                from: kakaoMap
            )
        }

        private var currentMapView: KakaoMap? {
            controller?.getView(
                mapViewName
            ) as? KakaoMap
        }

        private func applyMapLayout(
            mapView: KakaoMap,
            size: CGSize
        ) {
            guard size.width > 0,
                  size.height > 0
            else {
                return
            }

            mapView.viewRect = CGRect(
                origin: .zero,
                size: size
            )
        }

        private func renderMarkersIfNeeded() {
            guard needsMarkerRender,
                  let mapView = currentMapView,
                  mapView.viewRect.width > 0,
                  mapView.viewRect.height > 0
            else {
                return
            }

            installMarkerLayerIfNeeded(
                on: mapView
            )

            drawMarkers(
                on: mapView
            )

            needsMarkerRender = false
        }

        private func installMarkerLayerIfNeeded(
            on mapView: KakaoMap
        ) {
            let labelManager = mapView.getLabelManager()

            if labelManager.getLabelLayer(
                layerID: markerLayerID
            ) == nil {
                let options = LabelLayerOptions(
                    layerID: markerLayerID,
                    competitionType: .none,
                    competitionUnit: .symbolFirst,
                    orderType: .rank,
                    zOrder: 1
                )

                _ = labelManager.addLabelLayer(
                    option: options
                )
            }
        }

        private func drawMarkers(
            on mapView: KakaoMap
        ) {
            let labelManager = mapView.getLabelManager()

            guard let markerLayer = labelManager.getLabelLayer(
                layerID: markerLayerID
            ) else {
                return
            }

            markerLayer.clearAllItems()

            for marker in markers {
                let mapPoint = MapPoint(
                    longitude: marker.coordinate.longitude,
                    latitude: marker.coordinate.latitude
                )

                let isSelected = marker.id == selectedMarkerID

                let styleID = markerStyleID(
                    for: marker,
                    isSelected: isSelected
                )

                registerMarkerStyleIfNeeded(
                    styleID: styleID,
                    marker: marker,
                    isSelected: isSelected,
                    on: labelManager
                )

                let option = PoiOptions(
                    styleID: styleID,
                    poiID: marker.id
                )

                option.clickable = true
                option.rank = markerRank(
                    for: marker,
                    isSelected: isSelected
                )

                let poi = markerLayer.addPoi(
                    option: option,
                    at: mapPoint
                )

                poi?.show()
            }
        }

        private func markerStyleID(
            for marker: MapMarker,
            isSelected: Bool
        ) -> String {
            let kind: String

            switch marker {
            case .log:
                kind = "log"

            case .tourism:
                kind = "tourism"
            }

            let selection = isSelected
                ? "selected"
                : "normal"

            return "explore-map-\(kind)-\(selection)"
        }

        private func markerRank(
            for marker: MapMarker,
            isSelected: Bool
        ) -> Int {
            let baseRank: Int

            switch marker {
            case let .log(logMarker):
                baseRank = logMarker.sequence

            case .tourism:
                baseRank = 0
            }

            return isSelected
                ? 10_000 + baseRank
                : baseRank
        }

        private func registerMarkerStyleIfNeeded(
            styleID: String,
            marker: MapMarker,
            isSelected: Bool,
            on labelManager: LabelManager
        ) {
            guard !registeredMarkerStyleIDs.contains(styleID) else {
                return
            }

            let markerImage = makeMarkerImage(
                for: marker,
                isSelected: isSelected
            )

            let iconStyle = PoiIconStyle(
                symbol: markerImage,
                anchorPoint: CGPoint(
                    x: 0.5,
                    y: 0.5
                )
            )

            let poiStyle = PoiStyle(
                styleID: styleID,
                styles: [
                    PerLevelPoiStyle(
                        iconStyle: iconStyle,
                        level: 0
                    )
                ]
            )

            labelManager.addPoiStyle(
                poiStyle
            )

            registeredMarkerStyleIDs.insert(styleID)
        }

        private func makeMarkerImage(
            for marker: MapMarker,
            isSelected: Bool
        ) -> UIImage {
            let side: CGFloat = isSelected ? 48 : 40

            let size = CGSize(
                width: side,
                height: side
            )

            let renderer = UIGraphicsImageRenderer(
                size: size
            )

            return renderer.image { context in
                let circleRect = CGRect(
                    origin: .zero,
                    size: size
                ).insetBy(
                    dx: 3,
                    dy: 3
                )

                let fillColor: UIColor
                let symbolName: String

                switch marker {
                case .log:
                    fillColor = UIColor(
                        red: 0.72,
                        green: 0.95,
                        blue: 0.0,
                        alpha: 1
                    )
                    symbolName = "play.fill"

                case .tourism:
                    fillColor = UIColor(
                        red: 0.47,
                        green: 0.31,
                        blue: 0.75,
                        alpha: 1
                    )
                    symbolName = "sparkles"
                }

                context.cgContext.setFillColor(
                    fillColor.cgColor
                )
                context.cgContext.fillEllipse(
                    in: circleRect
                )

                context.cgContext.setStrokeColor(
                    (
                        isSelected
                            ? UIColor.black
                            : UIColor.white
                    ).cgColor
                )
                context.cgContext.setLineWidth(
                    isSelected ? 3 : 2
                )
                context.cgContext.strokeEllipse(
                    in: circleRect
                )

                let symbolConfiguration = UIImage.SymbolConfiguration(
                    pointSize: isSelected ? 18 : 15,
                    weight: .bold
                )

                let symbolImage = UIImage(
                    systemName: symbolName,
                    withConfiguration: symbolConfiguration
                )?.withTintColor(
                    .white,
                    renderingMode: .alwaysOriginal
                )

                let symbolSide: CGFloat = isSelected ? 18 : 15

                symbolImage?.draw(
                    in: CGRect(
                        x: (size.width - symbolSide) / 2,
                        y: (size.height - symbolSide) / 2,
                        width: symbolSide,
                        height: symbolSide
                    )
                )
            }
        }

        private func notifyViewportChanged(
            from mapView: KakaoMap
        ) {
            guard let viewport = makeViewport(
                from: mapView
            ) else {
                return
            }

            onViewportChanged(viewport)
        }

        private func makeViewport(
            from mapView: KakaoMap
        ) -> MapViewport? {
            let mapSize = mapView.viewRect.size

            guard mapSize.width > 0,
                  mapSize.height > 0
            else {
                return nil
            }

            let southWestPoint = mapView.getPosition(
                CGPoint(
                    x: 0,
                    y: mapSize.height
                )
            )

            let northEastPoint = mapView.getPosition(
                CGPoint(
                    x: mapSize.width,
                    y: 0
                )
            )

            let southWest = southWestPoint.wgsCoord
            let northEast = northEastPoint.wgsCoord

            return MapViewport(
                southLatitude: southWest.latitude,
                westLongitude: southWest.longitude,
                northLatitude: northEast.latitude,
                eastLongitude: northEast.longitude
            )
        }
    }
}

private struct ExploreMapSetupPlaceholder: View {
    var body: some View {
        Color(
            red: 0.16,
            green: 0.24,
            blue: 0.22
        )
        .overlay {
            VStack(spacing: 10) {
                Image(systemName: "map")
                    .font(.system(size: 34, weight: .semibold))

                Text("카카오 지도 앱 키가 필요해요")
                    .font(.headline)

                Text("Secrets.xcconfig의 KAKAO_NATIVE_APP_KEY를 확인해 주세요.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(24)
        }
    }
}
