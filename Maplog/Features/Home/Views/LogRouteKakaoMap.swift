//
//  LogRouteKakaoMap.swift
//  Maplog
//
//  Created by 한채림 on 8/23/26.
// 릴스 경로 전용 지도 파일

import SwiftUI
import UIKit
import KakaoMapsSDK

struct LogRouteKakaoMap: View {
    let points: [HomeMapRoutePointViewData]
    let selectedPointID: Int64?
    let onPointSelected: (Int64) -> Void
    let thumbnailDataByPointID: [Int64: Data]

    @State private var shouldDrawMap = true

    var body: some View {
        Group {
            if KakaoMapSDKConfiguration.hasUsableNativeAppKey {
                LogRouteKakaoMapRepresentable(
                    shouldDrawMap: $shouldDrawMap,
                    points: points,
                    selectedPointID: selectedPointID,
                    onPointSelected: onPointSelected,
                    thumbnailDataByPointID: thumbnailDataByPointID
                )
                .onAppear {
                    KakaoMapSDKConfiguration.initializeIfNeeded()
                    shouldDrawMap = true
                }
                .onDisappear {
                    shouldDrawMap = false
                }
            } else {
                LogRouteKakaoMapSetupPlaceholder()
            }
        }
    }
}

private struct LogRouteKakaoMapRepresentable: UIViewRepresentable {
    @Binding var shouldDrawMap: Bool

    let points: [HomeMapRoutePointViewData]
    let selectedPointID: Int64?
    let onPointSelected: (Int64) -> Void
    let thumbnailDataByPointID: [Int64: Data]

    func makeUIView(
        context: Context
    ) -> KMViewContainer {
        let view = KMViewContainer()
        view.sizeToFit()
        // 릴스 지도도 시스템 다크 모드 영향을 받지 않고 라이트 타일로 표시함.
        view.overrideUserInterfaceStyle = .light

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
        context.coordinator.updateRoute(
            points: points,
            thumbnailDataByPointID: thumbnailDataByPointID,
            selectedPointID: selectedPointID
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
            points: points,
            selectedPointID: selectedPointID,
            onPointSelected: onPointSelected,
            thumbnailDataByPointID: thumbnailDataByPointID
        )
    }

    final class Coordinator: NSObject, MapControllerDelegate {
        private let mapViewName = "home-log-route-map"

        private let routeShapeLayerID = "home-log-route-shape-layer"
        private let routeLineStyleID = "home-log-route-line-style"
        private let routeLineID = "home-log-route-line"

        private let markerLayerID = "home-log-route-marker-layer"

        private weak var viewContainer: KMViewContainer?
        private var controller: KMController?

        private var points: [HomeMapRoutePointViewData]
        private var selectedPointID: Int64?
        private let onPointSelected: (Int64) -> Void
        private var thumbnailDataByPointID: [Int64: Data]

        private var needsRouteRender = true
        private var needsCameraFit = true
        private var didRegisterRouteLineStyle = false
        private var registeredMarkerStyleIDs: Set<String> = []
        private var markerTapHandlers: [any DisposableEventHandler] = []

        init(
            points: [HomeMapRoutePointViewData],
            selectedPointID: Int64?,
            onPointSelected: @escaping (Int64) -> Void,
            thumbnailDataByPointID: [Int64: Data]
        ) {
            self.points = points
            self.selectedPointID = selectedPointID
            self.onPointSelected = onPointSelected
            self.thumbnailDataByPointID = thumbnailDataByPointID

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
            clearMarkerTapHandlers()

            controller?.pauseEngine()
            controller?.resetEngine()
        }

        func updateRoute(
            points: [HomeMapRoutePointViewData],
            thumbnailDataByPointID: [Int64: Data],
            selectedPointID: Int64?
        ) {
            let selectionChanged = self.selectedPointID != selectedPointID
            let routeChanged = self.points != points
            let thumbnailsChanged =
                self.thumbnailDataByPointID != thumbnailDataByPointID

            self.points = points
            self.thumbnailDataByPointID = thumbnailDataByPointID
            self.selectedPointID = selectedPointID

            if routeChanged || thumbnailsChanged || selectionChanged {
                needsRouteRender = true
            }

            if routeChanged {
                needsCameraFit = true
            }

            renderRouteIfNeeded()

        }

        @objc func addViews() {
            let mapviewInfo = MapviewInfo(
                viewName: mapViewName,
                viewInfoName: "map",
                defaultPosition: initialPosition,
                defaultLevel: 13
            )

            controller?.addView(mapviewInfo)
        }

        @objc func addViewSucceeded(
            _ viewName: String,
            viewInfoName: String
        ) {
            guard let size = viewContainer?.bounds.size else {
                return
            }

            applyMapLayoutIfReady(
                size: size
            )

            renderRouteIfNeeded()
        }

        @objc func containerDidResized(
            _ size: CGSize
        ) {
            applyMapLayoutIfReady(
                size: size
            )

            renderRouteIfNeeded()
        }

        @objc func addViewFailed(
            _ viewName: String,
            viewInfoName: String
        ) {
            print("Kakao map view failed: \(viewName)")
        }

        @objc func authenticationFailed(
            _ errorCode: Int,
            desc: String
        ) {
            print("Kakao map authentication failed: \(errorCode)")
        }

        @objc func authenticationSucceeded() {
            print("Kakao map authentication succeeded")
        }

        private var initialPosition: MapPoint {
            mapPoint(
                from: points.first
            ) ?? MapPoint(
                longitude: 127.0276,
                latitude: 37.4979
            )
        }

        private var currentMapView: KakaoMap? {
            controller?.getView(
                mapViewName
            ) as? KakaoMap
        }

        private func applyMapLayoutIfReady(
            size: CGSize
        ) {
            guard size.width > 0,
                  size.height > 0,
                  let mapView = currentMapView else {
                return
            }

            mapView.viewRect = CGRect(
                origin: .zero,
                size: size
            )
        }

        private func renderRouteIfNeeded() {
            guard needsRouteRender || needsCameraFit,
                  let mapView = currentMapView,
                  mapView.viewRect.width > 0,
                  mapView.viewRect.height > 0 else {
                return
            }

            installMapLayersIfNeeded(
                on: mapView
            )

            if needsRouteRender {
                drawRouteLine(
                    on: mapView
                )

                drawMarkers(
                    on: mapView
                )

                needsRouteRender = false
            }

            if needsCameraFit {
                fitCameraToRoute(
                    on: mapView
                )

                needsCameraFit = false
            }
        }

        private func installMapLayersIfNeeded(
            on mapView: KakaoMap
        ) {
            let shapeManager = mapView.getShapeManager()

            if shapeManager.getShapeLayer(
                layerID: routeShapeLayerID
            ) == nil {
                _ = shapeManager.addShapeLayer(
                    layerID: routeShapeLayerID,
                    zOrder: 0
                )
            }

            if !didRegisterRouteLineStyle {
                let lineStyle = PolylineStyle(
                    styles: [
                        PerLevelPolylineStyle(
                            // 마커와 장소 카드가 주인공이고, 선은 이동 순서만 보조한다.
                            bodyColor: UIColor(Color.maplogLime)
                                .withAlphaComponent(0.58),
                            bodyWidth: 4,
                            strokeColor: UIColor(
                                Color.maplogMapLightTextSecondary
                            ).withAlphaComponent(0.14),
                            strokeWidth: 1,
                            level: 0
                        )
                    ]
                )

                let styleSet = PolylineStyleSet(
                    styleSetID: routeLineStyleID,
                    styles: [lineStyle]
                )

                shapeManager.addPolylineStyleSet(
                    styleSet
                )

                didRegisterRouteLineStyle = true
            }

            let labelManager = mapView.getLabelManager()

            if labelManager.getLabelLayer(
                layerID: markerLayerID
            ) == nil {
                let option = LabelLayerOptions(
                    layerID: markerLayerID,
                    competitionType: .none,
                    competitionUnit: .symbolFirst,
                    orderType: .rank,
                    zOrder: 1
                )

                _ = labelManager.addLabelLayer(
                    option: option
                )
            }
        }

        private func drawRouteLine(
            on mapView: KakaoMap
        ) {
            let mapPoints = points.compactMap(
                mapPoint
            )

            guard let shapeLayer = mapView
                .getShapeManager()
                .getShapeLayer(
                    layerID: routeShapeLayerID
                ) else {
                return
            }

            guard mapPoints.count >= 2 else {
                shapeLayer
                    .getMapPolylineShape(
                        shapeID: routeLineID
                    )?
                    .hide()

                return
            }

            let line = MapPolyline(
                line: mapPoints,
                styleIndex: 0
            )

            if let existingRouteLine = shapeLayer
                .getMapPolylineShape(
                    shapeID: routeLineID
                ) {
                existingRouteLine.changeStyleAndData(
                    styleID: routeLineStyleID,
                    lines: [line]
                )

                existingRouteLine.show()
                return
            }

            let options = MapPolylineShapeOptions(
                shapeID: routeLineID,
                styleID: routeLineStyleID,
                zOrder: 0
            )

            options.polylines = [line]

            let routeLine = shapeLayer.addMapPolylineShape(
                options
            )

            routeLine?.show()
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

            clearMarkerTapHandlers()
            markerLayer.clearAllItems()

            for point in points {
                guard let mapPoint = mapPoint(
                    from: point
                ) else {
                    continue
                }

                let thumbnailData = thumbnailDataByPointID[
                    point.id
                ]

                let styleID = markerStyleID(
                    for: point,
                    hasThumbnail: thumbnailData != nil
                )

                registerMarkerStyleIfNeeded(
                    styleID: styleID,
                    sequence: point.sequence,
                    thumbnailData: thumbnailData,
                    isSelected: selectedPointID == point.id,
                    on: labelManager
                )

                let option = PoiOptions(
                    styleID: styleID,
                    poiID: "route-clip-\(point.id)"
                )

                option.clickable = true
                option.rank = point.sequence

                let poi = markerLayer.addPoi(
                    option: option,
                    at: mapPoint
                )

                let handler = poi?.addPoiTappedEventHandler(
                    target: self,
                    handler: { [weak self] _ in
                        { _ in
                            self?.onPointSelected(
                                point.id
                            )
                        }
                    }
                )

                if let handler {
                    markerTapHandlers.append(handler)
                }

                poi?.show()
            }
        }

        private func registerMarkerStyleIfNeeded(
            styleID: String,
            sequence: Int,
            thumbnailData: Data?,
            isSelected: Bool,
            on labelManager: LabelManager
        ) {
            guard !registeredMarkerStyleIDs.contains(
                styleID
            ) else {
                return
            }

            let markerImage = MaplogLogMarkerImage.image(
                thumbnailData: thumbnailData,
                isSelected: isSelected,
                sequence: sequence
            )

            let iconStyle = PoiIconStyle(
                symbol: markerImage,
                anchorPoint: CGPoint(
                    x: 0.5,
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

            registeredMarkerStyleIDs.insert(
                styleID
            )
        }

        private func markerStyleID(
            for point: HomeMapRoutePointViewData,
            hasThumbnail: Bool
        ) -> String {
            let imageState = hasThumbnail
                ? "thumbnail"
                : "fallback"

            let selectionState = selectedPointID == point.id ? "selected" : "normal"
            return "home-log-route-marker-\(point.id)-\(point.sequence)-\(imageState)-\(selectionState)"
        }

        private func fitCameraToRoute(
            on mapView: KakaoMap
        ) {
            let mapPoints = points.compactMap(
                mapPoint
            )

            guard let firstPoint = mapPoints.first else {
                return
            }

            if mapPoints.count == 1 {
                let cameraUpdate = CameraUpdate.make(
                    target: firstPoint,
                    zoomLevel: 13,
                    mapView: mapView
                )

                mapView.moveCamera(
                    cameraUpdate
                )

                return
            }

            let cameraUpdate = CameraUpdate.make(
                area: paddedRouteArea(
                    for: points
                )
            )

            mapView.moveCamera(
                cameraUpdate
            )
        }

        private func paddedRouteArea(
            for points: [HomeMapRoutePointViewData]
        ) -> AreaRect {
            let latitudes = points.map(\.latitude)
            let longitudes = points.map(\.longitude)

            let minimumLatitude = latitudes.min() ?? 37.4979
            let maximumLatitude = latitudes.max() ?? 37.4979
            let minimumLongitude = longitudes.min() ?? 127.0276
            let maximumLongitude = longitudes.max() ?? 127.0276

            let latitudePadding = max(
                (maximumLatitude - minimumLatitude) * 0.30,
                0.0015
            )

            let longitudePadding = max(
                (maximumLongitude - minimumLongitude) * 0.30,
                0.0015
            )

            let southWest = MapPoint(
                longitude: max(
                    -180,
                    minimumLongitude - longitudePadding
                ),
                latitude: max(
                    -90,
                    minimumLatitude - latitudePadding
                )
            )

            let northEast = MapPoint(
                longitude: min(
                    180,
                    maximumLongitude + longitudePadding
                ),
                latitude: min(
                    90,
                    maximumLatitude + latitudePadding
                )
            )

            return AreaRect(
                southWest: southWest,
                northEast: northEast
            )
        }

        private func mapPoint(
            from point: HomeMapRoutePointViewData?
        ) -> MapPoint? {
            guard let point else {
                return nil
            }

            return MapPoint(
                longitude: point.longitude,
                latitude: point.latitude
            )
        }

        private func clearMarkerTapHandlers() {
            markerTapHandlers.forEach {
                $0.dispose()
            }

            markerTapHandlers.removeAll()
        }
    }
}

private struct LogRouteKakaoMapSetupPlaceholder: View {
    var body: some View {
        Color.maplogMapLightCanvas
        .overlay {
            VStack(spacing: 10) {
                Image(systemName: "map")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.maplogMapLightTextPrimary)

                Text("카카오 지도 앱 키가 필요해요")
                    .font(.headline)
                    .foregroundStyle(Color.maplogMapLightTextPrimary)

                Text("Secrets.xcconfig의 KAKAO_NATIVE_APP_KEY를 확인해 주세요.")
                    .font(.caption)
                    .foregroundStyle(Color.maplogMapLightTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }
}
