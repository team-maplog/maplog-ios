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
    let thumbnailDataByMarkerID: [String: Data]
    let selectedMarkerID: String? // 현재 선택되어 강조 표시할 핀
    let currentLocation: MapCoordinate?
    let currentLocationFocusRequestID: UUID?

    let onViewportChanged: (MapViewport) -> Void
    let onMarkerSelected: (String) -> Void // 핀을 탭했을 때 ViewModel에 전달할 동작
    let onMapTapped: () -> Void

    @State private var shouldDrawMap = true

    var body: some View {
        Group {
            if KakaoMapSDKConfiguration.hasUsableNativeAppKey {
                ExploreKakaoMapRepresentable(
                    shouldDrawMap: $shouldDrawMap,
                    markers: markers,
                    thumbnailDataByMarkerID: thumbnailDataByMarkerID,
                    selectedMarkerID: selectedMarkerID,
                    currentLocation: currentLocation,
                    currentLocationFocusRequestID: currentLocationFocusRequestID,
                    onViewportChanged: onViewportChanged,
                    onMarkerSelected: onMarkerSelected,
                    onMapTapped: onMapTapped
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
    let thumbnailDataByMarkerID: [String: Data]
    let selectedMarkerID: String?
    let currentLocation: MapCoordinate?
    let currentLocationFocusRequestID: UUID?

    let onViewportChanged: (MapViewport) -> Void
    let onMarkerSelected: (String) -> Void
    let onMapTapped: () -> Void

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
            thumbnailDataByMarkerID: thumbnailDataByMarkerID,
            selectedMarkerID: selectedMarkerID
        )
        context.coordinator.updateCurrentLocation(
            currentLocation,
            focusRequestID: currentLocationFocusRequestID
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
            thumbnailDataByMarkerID: thumbnailDataByMarkerID,
            selectedMarkerID: selectedMarkerID,
            currentLocation: currentLocation,
            currentLocationFocusRequestID: currentLocationFocusRequestID,
            onViewportChanged: onViewportChanged,
            onMarkerSelected: onMarkerSelected,
            onMapTapped: onMapTapped
        )
    }

    final class Coordinator: NSObject, MapControllerDelegate, KakaoMapEventDelegate {
        private let mapViewName = "explore-map"
        private let markerLayerID = "explore-map-marker-layer"
        private let currentLocationLayerID = "explore-map-current-location-layer"
        private let currentLocationPoiID = "explore-map-current-location"
        private let currentLocationStyleID = "explore-map-current-location-style"

        private var markers: [MapMarker]
        private var thumbnailDataByMarkerID: [String: Data]
        private var selectedMarkerID: String?
        private var currentLocation: MapCoordinate?
        private var currentLocationFocusRequestID: UUID?
        private var handledCurrentLocationFocusRequestID: UUID?

        private let onViewportChanged: (MapViewport) -> Void
        private let onMarkerSelected: (String) -> Void
        private let onMapTapped: () -> Void

        private var needsMarkerRender = true
        private var needsCurrentLocationRender = true
        private var registeredMarkerStyleIDs: Set<String> = []
        private var isCurrentLocationStyleRegistered = false

        private weak var viewContainer: KMViewContainer?
        private var controller: KMController?


        init(
            markers: [MapMarker],
            thumbnailDataByMarkerID: [String: Data],
            selectedMarkerID: String?,
            currentLocation: MapCoordinate?,
            currentLocationFocusRequestID: UUID?,
            onViewportChanged: @escaping (MapViewport) -> Void,
            onMarkerSelected: @escaping (String) -> Void,
            onMapTapped: @escaping () -> Void
        ) {
            self.markers = markers
            self.thumbnailDataByMarkerID = thumbnailDataByMarkerID
            self.selectedMarkerID = selectedMarkerID
            self.currentLocation = currentLocation
            self.currentLocationFocusRequestID = currentLocationFocusRequestID
            self.onViewportChanged = onViewportChanged
            self.onMarkerSelected = onMarkerSelected
            self.onMapTapped = onMapTapped

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
            isCurrentLocationStyleRegistered = false
            needsMarkerRender = true
            needsCurrentLocationRender = true
            handledCurrentLocationFocusRequestID = nil
        }

        func updateMarkers(
            _ markers: [MapMarker],
            thumbnailDataByMarkerID: [String: Data],
            selectedMarkerID: String?
        ) {
            let markersChanged = self.markers != markers
            let thumbnailsChanged =
                self.thumbnailDataByMarkerID != thumbnailDataByMarkerID
            let selectionChanged =
                self.selectedMarkerID != selectedMarkerID

            self.markers = markers
            self.thumbnailDataByMarkerID = thumbnailDataByMarkerID
            self.selectedMarkerID = selectedMarkerID

            if markersChanged || thumbnailsChanged || selectionChanged {
                needsMarkerRender = true
            }

            renderMarkersIfNeeded()
        }

        func updateCurrentLocation(
            _ currentLocation: MapCoordinate?,
            focusRequestID: UUID?
        ) {
            let locationChanged = self.currentLocation != currentLocation

            self.currentLocation = currentLocation
            self.currentLocationFocusRequestID = focusRequestID

            if locationChanged {
                needsCurrentLocationRender = true
            }

            renderCurrentLocationIfNeeded()
            focusCurrentLocationIfNeeded()
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

        /// 지도 빈 곳을 눌렀다는 SDK 콜백이다.
        /// SwiftUI 제스처를 지도 위에 올리지 않아 드래그·핀치 동작을 막지 않는다.
        func kakaoMapDidTapped(
            kakaoMap: KakaoMap,
            point: CGPoint
        ) {
            onMapTapped()
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
            renderCurrentLocationIfNeeded()
            focusCurrentLocationIfNeeded()

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

        private func renderCurrentLocationIfNeeded() {
            guard needsCurrentLocationRender,
                  let mapView = currentMapView,
                  mapView.viewRect.width > 0,
                  mapView.viewRect.height > 0
            else {
                return
            }

            let labelManager = mapView.getLabelManager()

            installCurrentLocationLayerIfNeeded(
                on: mapView
            )

            guard let currentLocationLayer = labelManager.getLabelLayer(
                layerID: currentLocationLayerID
            ) else {
                return
            }

            currentLocationLayer.clearAllItems()

            guard let currentLocation else {
                needsCurrentLocationRender = false
                return
            }

            registerCurrentLocationStyleIfNeeded(
                on: labelManager
            )

            let option = PoiOptions(
                styleID: currentLocationStyleID,
                poiID: currentLocationPoiID
            )
            option.clickable = false
            option.rank = 20_000

            let poi = currentLocationLayer.addPoi(
                option: option,
                at: MapPoint(
                    longitude: currentLocation.longitude,
                    latitude: currentLocation.latitude
                )
            )
            poi?.show()

            needsCurrentLocationRender = false
        }

        private func installCurrentLocationLayerIfNeeded(
            on mapView: KakaoMap
        ) {
            let labelManager = mapView.getLabelManager()

            if labelManager.getLabelLayer(
                layerID: currentLocationLayerID
            ) == nil {
                let options = LabelLayerOptions(
                    layerID: currentLocationLayerID,
                    competitionType: .none,
                    competitionUnit: .symbolFirst,
                    orderType: .rank,
                    zOrder: 2
                )

                _ = labelManager.addLabelLayer(
                    option: options
                )
            }
        }

        private func registerCurrentLocationStyleIfNeeded(
            on labelManager: LabelManager
        ) {
            guard !isCurrentLocationStyleRegistered else {
                return
            }

            let iconStyle = PoiIconStyle(
                symbol: makeCurrentLocationImage(),
                anchorPoint: CGPoint(x: 0.5, y: 0.5)
            )
            let poiStyle = PoiStyle(
                styleID: currentLocationStyleID,
                styles: [
                    PerLevelPoiStyle(
                        iconStyle: iconStyle,
                        level: 0
                    )
                ]
            )

            labelManager.addPoiStyle(poiStyle)
            isCurrentLocationStyleRegistered = true
        }

        private func makeCurrentLocationImage() -> UIImage {
            let size = CGSize(width: 24, height: 24)

            return UIGraphicsImageRenderer(size: size).image { context in
                let outerRect = CGRect(
                    x: 3,
                    y: 3,
                    width: 18,
                    height: 18
                )
                let innerRect = outerRect.insetBy(dx: 3, dy: 3)

                UIColor.white.setFill()
                context.cgContext.fillEllipse(in: outerRect)

                UIColor(
                    red: 0.05,
                    green: 0.43,
                    blue: 0.95,
                    alpha: 1
                )
                .setFill()
                context.cgContext.fillEllipse(in: innerRect)
            }
        }

        private func focusCurrentLocationIfNeeded() {
            guard let focusRequestID = currentLocationFocusRequestID,
                  focusRequestID != handledCurrentLocationFocusRequestID,
                  let currentLocation,
                  let mapView = currentMapView
            else {
                return
            }

            let cameraUpdate = CameraUpdate.make(
                target: MapPoint(
                    longitude: currentLocation.longitude,
                    latitude: currentLocation.latitude
                ),
                zoomLevel: 15,
                mapView: mapView
            )

            mapView.moveCamera(cameraUpdate)
            handledCurrentLocationFocusRequestID = focusRequestID
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
            let selection = isSelected
                ? "selected"
                : "normal"
            let imageState = thumbnailDataByMarkerID[marker.id] == nil
                ? "placeholder"
                : "thumbnail"

            // KakaoMap의 PoiStyle은 한 번 등록하면 같은 styleID의 이미지를 바꿀 수 없다.
            // 따라서 썸네일을 쓰는 맵로그는 marker.id까지 넣어 각각의 이미지 스타일을 만든다.
            switch marker {
            case .log:
                return "explore-map-\(marker.id)-\(imageState)-\(selection)"

            case .tourism:
                return "explore-map-tourism-\(selection)"
            }
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
                thumbnailData: thumbnailDataByMarkerID[marker.id],
                isSelected: isSelected
            )

            let iconStyle = PoiIconStyle(
                symbol: markerImage,
                anchorPoint: CGPoint(
                    x: 0.5,
                    y: marker.kind == .tourism ? 1 : 0.5
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
            thumbnailData: Data?,
            isSelected: Bool
        ) -> UIImage {
            switch marker {
            case .log:
                return makeLogMarkerImage(
                    thumbnailData: thumbnailData,
                    isSelected: isSelected
                )

            case .tourism:
                return makeTourismMarkerImage(
                    isSelected: isSelected
                )
            }
        }

        private func makeLogMarkerImage(
            thumbnailData: Data?,
            isSelected: Bool
        ) -> UIImage {
            let side: CGFloat = isSelected ? 52 : 44
            let size = CGSize(width: side, height: side)
            let cardRect = CGRect(
                x: 2,
                y: 2,
                width: side - 4,
                height: side - 4
            )
            let cardPath = UIBezierPath(
                roundedRect: cardRect,
                cornerRadius: isSelected ? 12 : 10
            )

            return UIGraphicsImageRenderer(size: size).image { context in
                let graphicsContext = context.cgContext

                UIColor.white.setFill()
                cardPath.fill()

                let imageRect = cardRect.insetBy(dx: 2, dy: 2)
                let imagePath = UIBezierPath(
                    roundedRect: imageRect,
                    cornerRadius: isSelected ? 10 : 8
                )

                graphicsContext.saveGState()
                imagePath.addClip()

                if let thumbnailData,
                   let thumbnailImage = UIImage(data: thumbnailData) {
                    drawAspectFill(
                        thumbnailImage,
                        in: imageRect
                    )
                } else {
                    UIColor(
                        red: 0.25,
                        green: 0.29,
                        blue: 0.25,
                        alpha: 1
                    )
                    .setFill()
                    graphicsContext.fill(imageRect)

                    let symbolSize: CGFloat = isSelected ? 19 : 16
                    UIImage(
                        systemName: "play.fill",
                        withConfiguration: UIImage.SymbolConfiguration(
                            pointSize: symbolSize,
                            weight: .bold
                        )
                    )?
                    .withTintColor(
                        .white,
                        renderingMode: .alwaysOriginal
                    )
                    .draw(
                        in: CGRect(
                            x: imageRect.midX - symbolSize / 2,
                            y: imageRect.midY - symbolSize / 2,
                            width: symbolSize,
                            height: symbolSize
                        )
                    )
                }

                graphicsContext.restoreGState()

                (
                    isSelected
                        ? UIColor(
                            red: 0.72,
                            green: 0.95,
                            blue: 0,
                            alpha: 1
                        )
                        : UIColor.white
                )
                .setStroke()
                cardPath.lineWidth = isSelected ? 2.5 : 1.5
                cardPath.stroke()
            }
        }

        private func makeTourismMarkerImage(
            isSelected: Bool
        ) -> UIImage {
            let size = CGSize(
                width: isSelected ? 40 : 34,
                height: isSelected ? 50 : 43
            )
            let width = size.width
            let height = size.height

            return UIGraphicsImageRenderer(size: size).image { context in
                let path = UIBezierPath()

                path.move(
                    to: CGPoint(
                        x: width / 2,
                        y: height - 3
                    )
                )
                path.addCurve(
                    to: CGPoint(x: 4, y: height * 0.45),
                    controlPoint1: CGPoint(x: width * 0.30, y: height * 0.76),
                    controlPoint2: CGPoint(x: 4, y: height * 0.63)
                )
                path.addCurve(
                    to: CGPoint(x: width / 2, y: 3),
                    controlPoint1: CGPoint(x: 4, y: height * 0.16),
                    controlPoint2: CGPoint(x: width * 0.28, y: 3)
                )
                path.addCurve(
                    to: CGPoint(x: width - 4, y: height * 0.45),
                    controlPoint1: CGPoint(x: width * 0.72, y: 3),
                    controlPoint2: CGPoint(x: width - 4, y: height * 0.16)
                )
                path.addCurve(
                    to: CGPoint(x: width / 2, y: height - 3),
                    controlPoint1: CGPoint(x: width - 4, y: height * 0.63),
                    controlPoint2: CGPoint(x: width * 0.70, y: height * 0.76)
                )
                path.close()

                let graphicsContext = context.cgContext
                graphicsContext.setShadow(
                    offset: CGSize(width: 0, height: 4),
                    blur: 7,
                    color: UIColor.black
                        .withAlphaComponent(0.24)
                        .cgColor
                )
                UIColor(
                    red: 0.56,
                    green: 0.45,
                    blue: 0.91,
                    alpha: 1
                )
                .setFill()
                path.fill()
                graphicsContext.setShadow(offset: .zero, blur: 0)

                UIColor.white.setStroke()
                path.lineWidth = isSelected ? 3 : 2
                path.stroke()

                let symbolSide: CGFloat = isSelected ? 18 : 15
                let symbolImage = UIImage(
                    systemName: "building.columns.fill",
                    withConfiguration: UIImage.SymbolConfiguration(
                        pointSize: symbolSide,
                        weight: .semibold
                    )
                )?
                .withTintColor(
                    .white,
                    renderingMode: .alwaysOriginal
                )

                symbolImage?.draw(
                    in: CGRect(
                        x: width / 2 - symbolSide / 2,
                        y: height * 0.38 - symbolSide / 2,
                        width: symbolSide,
                        height: symbolSide
                    )
                )
            }
        }

        private func drawAspectFill(
            _ image: UIImage,
            in rect: CGRect
        ) {
            let scale = max(
                rect.width / image.size.width,
                rect.height / image.size.height
            )
            let drawSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            let drawRect = CGRect(
                x: rect.midX - drawSize.width / 2,
                y: rect.midY - drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )

            image.draw(in: drawRect)
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
