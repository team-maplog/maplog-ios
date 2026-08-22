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

    @State private var shouldDrawMap = true

    var body: some View {
        Group {
            if KakaoMapSDKConfiguration.hasUsableNativeAppKey {
                LogRouteKakaoMapRepresentable(
                    shouldDrawMap: $shouldDrawMap,
                    points: points,
                    selectedPointID: selectedPointID,
                    onPointSelected: onPointSelected
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
        context.coordinator.updateRoute(
            points: points,
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
            onPointSelected: onPointSelected
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

        private var needsRouteRender = true
        private var needsCameraFit = true
        private var didRegisterRouteLineStyle = false
        private var registeredMarkerStyleIDs: Set<String> = []
        private var markerTapHandlers: [any DisposableEventHandler] = []

        init(
            points: [HomeMapRoutePointViewData],
            selectedPointID: Int64?,
            onPointSelected: @escaping (Int64) -> Void
        ) {
            self.points = points
            self.selectedPointID = selectedPointID
            self.onPointSelected = onPointSelected

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
            selectedPointID: Int64?
        ) {
            let routeChanged = self.points != points
            let selectedPointChanged =
                self.selectedPointID != selectedPointID

            self.points = points
            self.selectedPointID = selectedPointID

            if routeChanged {
                needsRouteRender = true
                needsCameraFit = true
            }

            renderRouteIfNeeded()

            if !routeChanged,
               selectedPointChanged {
                moveCameraToSelectedPointIfPossible()
            }
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
                            bodyColor: UIColor(
                                red: 0.72,
                                green: 0.95,
                                blue: 0.0,
                                alpha: 1
                            ),
                            bodyWidth: 7,
                            strokeColor: UIColor.black.withAlphaComponent(0.18),
                            strokeWidth: 2,
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

                let styleID = markerStyleID(
                    for: point
                )

                registerMarkerStyleIfNeeded(
                    styleID: styleID,
                    sequence: point.sequence,
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
            on labelManager: LabelManager
        ) {
            guard !registeredMarkerStyleIDs.contains(
                styleID
            ) else {
                return
            }

            let markerImage = makeMarkerImage(
                sequence: sequence
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

            registeredMarkerStyleIDs.insert(
                styleID
            )
        }

        private func markerStyleID(
            for point: HomeMapRoutePointViewData
        ) -> String {
            "home-log-route-marker-\(point.id)-\(point.sequence)"
        }

        private func makeMarkerImage(
            sequence: Int
        ) -> UIImage {
            let size = CGSize(
                width: 44,
                height: 44
            )

            let renderer = UIGraphicsImageRenderer(
                size: size
            )

            return renderer.image { context in
                let circleRect = CGRect(
                    origin: .zero,
                    size: size
                ).insetBy(
                    dx: 2,
                    dy: 2
                )

                context.cgContext.setFillColor(
                    UIColor(
                        red: 0.72,
                        green: 0.95,
                        blue: 0.0,
                        alpha: 1
                    ).cgColor
                )

                context.cgContext.fillEllipse(
                    in: circleRect
                )

                context.cgContext.setStrokeColor(
                    UIColor.black
                        .withAlphaComponent(0.22)
                        .cgColor
                )

                context.cgContext.setLineWidth(2)
                context.cgContext.strokeEllipse(
                    in: circleRect
                )

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(
                        ofSize: 17,
                        weight: .bold
                    ),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphStyle
                ]

                let textRect = CGRect(
                    x: 0,
                    y: 11,
                    width: size.width,
                    height: 24
                )

                String(sequence).draw(
                    in: textRect,
                    withAttributes: attributes
                )
            }
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
                    zoomLevel: 15,
                    mapView: mapView
                )

                mapView.moveCamera(
                    cameraUpdate
                )

                return
            }

            let area = AreaRect(
                points: mapPoints
            )

            let cameraUpdate = CameraUpdate.make(
                area: area
            )

            mapView.moveCamera(
                cameraUpdate
            )
        }

        private func moveCameraToSelectedPointIfPossible() {
            guard let mapView = currentMapView,
                  let selectedPointID,
                  let point = points.first(
                    where: { $0.id == selectedPointID }
                  ),
                  let mapPoint = mapPoint(
                    from: point
                  ) else {
                return
            }

            let cameraUpdate = CameraUpdate.make(
                target: mapPoint,
                zoomLevel: 15,
                mapView: mapView
            )

            mapView.moveCamera(
                cameraUpdate
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
        Color(
            red: 0.16,
            green: 0.24,
            blue: 0.22
        )
        .overlay {
            VStack(spacing: 10) {
                Image(systemName: "map")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)

                Text("카카오 지도 앱 키가 필요해요")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Secrets.xcconfig의 KAKAO_NATIVE_APP_KEY를 확인해 주세요.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }
}
