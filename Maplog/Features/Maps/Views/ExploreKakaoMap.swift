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
    var searchFocusRequest: MapCameraFocusRequest? = nil

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
                    searchFocusRequest: searchFocusRequest,
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
    var searchFocusRequest: MapCameraFocusRequest? = nil

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

        context.coordinator.updateSearchFocus(searchFocusRequest)

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
        // KakaoMap이 지도 내부 레이어로 쓰는 0~4,999를 피하고,
        // 사용자 레이블에 허용된 5,000 이상 영역을 사용한다.
        private let markerLayerZOrder = 5_000
        private let currentLocationPulseLayerID = "explore-map-current-location-pulse-layer"
        private let currentLocationLayerID = "explore-map-current-location-layer"
        private let currentLocationPulseLayerZOrder = 5_001
        private let currentLocationLayerZOrder = 5_002
        private let currentLocationPulsePoiID = "explore-map-current-location-pulse"
        private let currentLocationPoiID = "explore-map-current-location"
        private let currentLocationPulseStyleID = "explore-map-current-location-pulse-style"
        private let currentLocationStyleID = "explore-map-current-location-style"
        private let currentLocationPulseAnimatorID = "explore-map-current-location-pulse-animator"

        private var markers: [MapMarker]
        private var thumbnailDataByMarkerID: [String: Data]
        private var selectedMarkerID: String?
        private var currentLocation: MapCoordinate?
        private var currentLocationFocusRequestID: UUID?
        private var handledCurrentLocationFocusRequestID: UUID?
        private var searchFocusRequest: MapCameraFocusRequest?
        private var handledSearchFocusID: UUID?

        func updateSearchFocus(_ request: MapCameraFocusRequest?) {
            searchFocusRequest = request
            focusSearchResultIfNeeded()
        }

        private func focusSearchResultIfNeeded() {
            guard let request = searchFocusRequest, request.id != handledSearchFocusID,
                  let mapView = currentMapView else { return }
            // 검색 좌표는 카메라만 움직인다. 실제 내 위치 도트와 섞지 않는다.
            let update = CameraUpdate.make(
                target: MapPoint(longitude: request.coordinate.longitude, latitude: request.coordinate.latitude),
                zoomLevel: 15, mapView: mapView
            )
            mapView.moveCamera(update)
            handledSearchFocusID = request.id
        }


        private let onViewportChanged: (MapViewport) -> Void
        private let onMarkerSelected: (String) -> Void
        private let onMapTapped: () -> Void

        private var needsMarkerRender = true
        private var needsCurrentLocationRender = true
        private var registeredMarkerStyleIDs: Set<String> = []
        private var isCurrentLocationPulseStyleRegistered = false
        private var isCurrentLocationStyleRegistered = false
        private var activeCurrentLocationPulseID: UUID?

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
            isCurrentLocationPulseStyleRegistered = false
            isCurrentLocationStyleRegistered = false
            activeCurrentLocationPulseID = nil
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
            focusSearchResultIfNeeded()
        }

        @objc func addViews() {
            let initialPosition = MapPoint(
                longitude: currentLocation?.longitude ?? 127.0479,
                latitude: currentLocation?.latitude ?? 37.5446
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
            focusSearchResultIfNeeded()

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
                    // 로그 썸네일과 관광 말풍선이 도로·역·장소 등 모든 지도
                    // 라벨 영역과 경쟁한다. Maplog 마커 레이어를 높게 두어
                    // 겹치는 기본 라벨은 숨기고, 같은 레이어에서는 rank로 고른다.
                    competitionType: .all,
                    competitionUnit: .symbolFirst,
                    orderType: .rank,
                    zOrder: markerLayerZOrder
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

            guard let currentLocationPulseLayer = labelManager.getLabelLayer(
                layerID: currentLocationPulseLayerID
            ),
            let currentLocationLayer = labelManager.getLabelLayer(
                layerID: currentLocationLayerID
            )
            else {
                return
            }

            invalidateCurrentLocationPulse(
                on: labelManager
            )
            currentLocationPulseLayer.clearAllItems()
            currentLocationLayer.clearAllItems()

            guard let currentLocation else {
                needsCurrentLocationRender = false
                return
            }

            registerCurrentLocationStyleIfNeeded(
                on: labelManager
            )

            let position = MapPoint(
                longitude: currentLocation.longitude,
                latitude: currentLocation.latitude
            )

            let pulseOption = PoiOptions(
                styleID: currentLocationPulseStyleID,
                poiID: currentLocationPulsePoiID
            )
            pulseOption.clickable = false
            pulseOption.rank = 19_999

            let currentLocationOption = PoiOptions(
                styleID: currentLocationStyleID,
                poiID: currentLocationPoiID
            )
            currentLocationOption.clickable = false
            currentLocationOption.rank = 20_000

            let pulsePoi = currentLocationPulseLayer.addPoi(
                option: pulseOption,
                at: position
            )
            pulsePoi?.show()

            let currentLocationPoi = currentLocationLayer.addPoi(
                option: currentLocationOption,
                at: position
            )
            currentLocationPoi?.show()

            if let pulsePoi {
                startCurrentLocationPulse(
                    for: pulsePoi,
                    on: labelManager
                )
            }

            needsCurrentLocationRender = false
        }

        private func installCurrentLocationLayerIfNeeded(
            on mapView: KakaoMap
        ) {
            let labelManager = mapView.getLabelManager()

            addCurrentLocationLayerIfNeeded(
                layerID: currentLocationPulseLayerID,
                zOrder: currentLocationPulseLayerZOrder,
                labelManager: labelManager
            )
            addCurrentLocationLayerIfNeeded(
                layerID: currentLocationLayerID,
                zOrder: currentLocationLayerZOrder,
                labelManager: labelManager
            )
        }

        private func addCurrentLocationLayerIfNeeded(
            layerID: String,
            zOrder: Int,
            labelManager: LabelManager
        ) {
            guard labelManager.getLabelLayer(
                layerID: layerID
            ) == nil else {
                return
            }

            let options = LabelLayerOptions(
                layerID: layerID,
                competitionType: .none,
                competitionUnit: .symbolFirst,
                orderType: .rank,
                zOrder: zOrder
            )

            _ = labelManager.addLabelLayer(
                option: options
            )
        }

        private func registerCurrentLocationStyleIfNeeded(
            on labelManager: LabelManager
        ) {
            if !isCurrentLocationPulseStyleRegistered {
                let pulseIconStyle = PoiIconStyle(
                    symbol: makeCurrentLocationPulseImage(),
                    anchorPoint: CGPoint(x: 0.5, y: 0.5)
                )
                let pulseStyle = PoiStyle(
                    styleID: currentLocationPulseStyleID,
                    styles: [
                        PerLevelPoiStyle(
                            iconStyle: pulseIconStyle,
                            level: 0
                        )
                    ]
                )

                labelManager.addPoiStyle(pulseStyle)
                isCurrentLocationPulseStyleRegistered = true
            }

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
            let ringRect = CGRect(x: 2, y: 2, width: 20, height: 20)
            let whiteBorderRect = CGRect(x: 5, y: 5, width: 14, height: 14)
            let dotRect = CGRect(x: 8, y: 8, width: 8, height: 8)
            let blue = UIColor(
                red: 0.165,
                green: 0.486,
                blue: 1,
                alpha: 1
            )

            return UIGraphicsImageRenderer(size: size).image { context in
                context.cgContext.setLineWidth(2)
                blue.withAlphaComponent(0.3).setStroke()
                context.cgContext.strokeEllipse(in: ringRect)

                context.cgContext.saveGState()
                context.cgContext.setShadow(
                    offset: CGSize(width: 0, height: 3),
                    blur: 6,
                    color: blue.withAlphaComponent(0.35).cgColor
                )
                UIColor.white.setFill()
                context.cgContext.fillEllipse(in: whiteBorderRect)
                context.cgContext.restoreGState()

                blue.setFill()
                context.cgContext.fillEllipse(in: dotRect)
            }
        }

        private func makeCurrentLocationPulseImage() -> UIImage {
            let size = CGSize(width: 18, height: 18)
            let pulseRect = CGRect(x: 2, y: 2, width: 14, height: 14)
            let blue = UIColor(
                red: 0.165,
                green: 0.486,
                blue: 1,
                alpha: 1
            )

            return UIGraphicsImageRenderer(size: size).image { context in
                context.cgContext.setLineWidth(2)
                blue.withAlphaComponent(0.55).setStroke()
                context.cgContext.strokeEllipse(in: pulseRect)
            }
        }

        private func startCurrentLocationPulse(
            for pulsePoi: Poi,
            on labelManager: LabelManager,
            pulseID: UUID = UUID()
        ) {
            activeCurrentLocationPulseID = pulseID
            removeCurrentLocationPulseAnimator(
                from: labelManager
            )

            let effect = ScaleAlphaAnimationEffect()
            effect.hideAtStop = false
            effect.removeAtStop = false
            effect.resetToInitialState = true
            effect.addKeyframe(
                ScaleAlphaAnimationKeyFrame(
                    scale: makeVector(x: 1.7, y: 1.7),
                    alpha: 0,
                    interpolation: makeAnimationInterpolation(
                        duration: 1_800,
                        method: .cubicOut
                    )
                )
            )

            guard let animator = labelManager.addPoiAnimator(
                animatorID: currentLocationPulseAnimatorID,
                effect: effect
            ) else {
                return
            }

            animator.setStopCallback { [weak self] _ in
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 0.2
                ) { [weak self] in
                    guard let self,
                          self.activeCurrentLocationPulseID == pulseID,
                          self.currentLocation != nil,
                          let labelManager = self.currentMapView?.getLabelManager(),
                          let pulseLayer = labelManager.getLabelLayer(
                            layerID: self.currentLocationPulseLayerID
                          ),
                          let nextPulsePoi = pulseLayer.getPoi(
                            poiID: self.currentLocationPulsePoiID
                          )
                    else {
                        return
                    }

                    self.startCurrentLocationPulse(
                        for: nextPulsePoi,
                        on: labelManager,
                        pulseID: pulseID
                    )
                }
            }
            animator.addPoi(pulsePoi)
            animator.start()
        }

        private func invalidateCurrentLocationPulse(
            on labelManager: LabelManager
        ) {
            activeCurrentLocationPulseID = nil
            removeCurrentLocationPulseAnimator(
                from: labelManager
            )
        }

        private func removeCurrentLocationPulseAnimator(
            from labelManager: LabelManager
        ) {
            labelManager.getPoiAnimator(
                animatorID: currentLocationPulseAnimatorID
            )?
            .setStopCallback(nil)
            labelManager.removePoiAnimator(
                animatorID: currentLocationPulseAnimatorID
            )
        }

        private func makeVector(
            x: Double,
            y: Double
        ) -> Vector2 {
            var vector = Vector2()
            vector.x = x
            vector.y = y
            return vector
        }

        private func makeAnimationInterpolation(
            duration: UInt32,
            method: InterpolationMethodType
        ) -> AnimationInterpolation {
            var interpolation = AnimationInterpolation()
            interpolation.duration = duration
            interpolation.method = method
            return interpolation
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

            case let .tourism(tourismMarker):
                // 말풍선마다 장소명이 다르므로 관광 ID까지 포함해 개별 스타일로 등록한다.
                // 응답 category가 달라졌을 때도 기존 스타일을 재사용하지 않도록 함께 구분한다.
                return "explore-map-tourism-\(marker.id)-\(tourismMarker.category.rawValue.lowercased())-\(selection)"
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
                    // 포인터의 끝이 실제 지도 좌표를 정확히 가리킨다.
                    y: 1
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
                return MaplogLogMarkerImage.image(
                    thumbnailData: thumbnailData,
                    isSelected: isSelected
                )

            case let .tourism(tourismMarker):
                return makeTourismMarkerImage(
                    marker: tourismMarker,
                    isSelected: isSelected
                )
            }
        }

        private func makeTourismMarkerImage(
            marker: TourismMapMarker,
            isSelected: Bool
        ) -> UIImage {
            let title: String
            if let markerName = marker.name?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !markerName.isEmpty {
                title = markerName
            } else {
                title = "관광 장소"
            }
            let font = UIFont.systemFont(
                ofSize: isSelected ? 10 : 9,
                weight: .medium
            )
            let horizontalInset: CGFloat = isSelected ? 6 : 5.5
            let iconSize: CGFloat = isSelected ? 14 : 12
            let iconGap: CGFloat = 3
            let maximumTitleWidth: CGFloat = isSelected ? 74 : 64
            let measurementTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(
                    red: 0.11,
                    green: 0.13,
                    blue: 0.17,
                    alpha: 1
                )
            ]
            let measuredTitleWidth = ceil(
                (title as NSString).boundingRect(
                    with: CGSize(
                        width: maximumTitleWidth,
                        height: font.lineHeight
                    ),
                    options: .usesLineFragmentOrigin,
                    attributes: measurementTitleAttributes,
                    context: nil
                ).width
            )
            let titleWidth = min(
                maximumTitleWidth,
                max(18, measuredTitleWidth)
            )
            let bubbleHeight: CGFloat = isSelected ? 29 : 25
            let pointerHeight: CGFloat = 4
            let bubbleWidth = horizontalInset * 2
                + iconSize
                + iconGap
                + titleWidth
            let size = CGSize(
                width: bubbleWidth + 2,
                height: bubbleHeight + pointerHeight + 1
            )
            let bubbleRect = CGRect(
                x: 1,
                y: 1,
                width: bubbleWidth,
                height: bubbleHeight
            )
            let bubblePath = UIBezierPath(
                roundedRect: bubbleRect,
                cornerRadius: bubbleHeight / 2
            )
            let pointerPath = UIBezierPath()
            pointerPath.move(
                to: CGPoint(
                    x: bubbleRect.midX - (isSelected ? 4 : 3.5),
                    y: bubbleRect.maxY - 1
                )
            )
            pointerPath.addLine(
                to: CGPoint(
                    x: bubbleRect.midX,
                    y: size.height
                )
            )
            pointerPath.addLine(
                to: CGPoint(
                    x: bubbleRect.midX + (isSelected ? 4 : 3.5),
                    y: bubbleRect.maxY - 1
                )
            )
            pointerPath.close()
            let visualStyle = TourismMapMarkerAppearance.style(
                for: marker.category
            )
            let bubbleColor = UIColor.white
            let textColor = UIColor(red: 0.11, green: 0.13, blue: 0.17, alpha: 1)
            let iconBackgroundColor = visualStyle.color.withAlphaComponent(0.14)
            let iconColor = visualStyle.color
            let borderColor = visualStyle.color.withAlphaComponent(isSelected ? 1 : 0.28)

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]

            return UIGraphicsImageRenderer(size: size).image { context in
                let graphicsContext = context.cgContext

                graphicsContext.saveGState()
                graphicsContext.setShadow(
                    offset: CGSize(width: 0, height: 1),
                    blur: 2.5,
                    color: UIColor.black.withAlphaComponent(0.16).cgColor
                )
                bubbleColor.setFill()
                bubblePath.fill()
                pointerPath.fill()
                graphicsContext.restoreGState()

                let iconRect = CGRect(
                    x: horizontalInset,
                    y: bubbleRect.midY - iconSize / 2,
                    width: iconSize,
                    height: iconSize
                )
                iconBackgroundColor.setFill()
                UIBezierPath(
                    ovalIn: iconRect
                )
                .fill()

                let symbolSize: CGFloat = isSelected ? 8 : 7
                UIImage(
                    systemName: visualStyle.symbolName,
                    withConfiguration: UIImage.SymbolConfiguration(
                        pointSize: symbolSize,
                        weight: .semibold
                    )
                )?
                .withTintColor(iconColor, renderingMode: .alwaysOriginal)
                .draw(
                    in: CGRect(
                        x: iconRect.midX - symbolSize / 2,
                        y: iconRect.midY - symbolSize / 2,
                        width: symbolSize,
                        height: symbolSize
                    )
                )

                let textRect = CGRect(
                    x: iconRect.maxX + iconGap,
                    y: bubbleRect.midY - font.lineHeight / 2,
                    width: titleWidth,
                    height: font.lineHeight
                )
                title.draw(
                    with: textRect,
                    options: [
                        .usesLineFragmentOrigin,
                        .truncatesLastVisibleLine
                    ],
                    attributes: titleAttributes,
                    context: nil
                )

                borderColor.setStroke()
                bubblePath.lineWidth = isSelected ? 1.25 : 1
                bubblePath.stroke()
                pointerPath.lineWidth = isSelected ? 1.25 : 1
                pointerPath.stroke()
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
