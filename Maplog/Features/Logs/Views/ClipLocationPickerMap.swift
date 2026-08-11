//
//  Untitled.swift
//  Maplog
//
//  Created by 한채림 on 8/11/26.
// 지도 선택
//akao UIKit 지도와 SwiftUI 화면을 연결하고, 지도 탭 좌표를 밖으로 전달

import SwiftUI
import UIKit
import KakaoMapsSDK

struct ClipLocationPickerMap: View {
    let location: LogLocationDraft
    let onLocationSelected: (Double, Double) -> Void

    @State private var shouldDrawMap = true


    var body: some View {
        Group {
            if KakaoMapSDKConfiguration.hasUsableNativeAppKey {
                ZStack{
                    ClipLocationPickerMapRepresentable(
                        shouldDrawMap: $shouldDrawMap,
                        location: location,
                        onLocationSelected: onLocationSelected
                    )
                    fixedCenterPin
                }
                .onAppear {
                    KakaoMapSDKConfiguration.initializeIfNeeded()
                    shouldDrawMap = true
                }
                .onDisappear {
                    shouldDrawMap = false
                }
            } else {
                ClipLocationPickerMapPlaceholder()
            }
        }
    }

    private var fixedCenterPin: some View {
        Image(systemName: "mappin.circle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.maplogInk)
                .shadow(
                    color: .black.opacity(0.24),
                    radius: 4,
                    y: 2
                )
                .offset(y: -15)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
    }
}



private struct ClipLocationPickerMapRepresentable: UIViewRepresentable {
    @Binding var shouldDrawMap: Bool

    let location: LogLocationDraft
    let onLocationSelected: (Double, Double) -> Void

    func makeUIView(context: Context) -> KMViewContainer {
            let view = KMViewContainer()
            view.sizeToFit()

            context.coordinator.createController(with: view)
            context.coordinator.prepareEngineIfNeeded()

            return view
        }

        func updateUIView(
            _ uiView: KMViewContainer,
            context: Context
        ) {
            context.coordinator.updateSelectedLocation(location)

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
                location: location,
                onLocationSelected: onLocationSelected
            )
        }

    final class Coordinator: NSObject, MapControllerDelegate, KakaoMapEventDelegate {
            private let mapViewName = "clip-location-picker-map"

            private var needsInitialCameraMove = true

            private var selectedLatitude: Double
            private var selectedLongitude: Double
            private var selectedPosition: MapPoint

            private let onLocationSelected: (Double, Double) -> Void

            private weak var viewContainer: KMViewContainer?
            private var controller: KMController?

            private var shouldIgnoreNextCameraStop = true  // 카메라 이동을 사용자 선택으로 오해하지 않도록 막아줌, 원래 저장된 주소를 실수로 지우지 않기 위해

            init(
                location: LogLocationDraft,
                onLocationSelected: @escaping (Double, Double) -> Void
            ) {
                selectedLatitude = location.latitude
                selectedLongitude = location.longitude
                selectedPosition = MapPoint(
                    longitude: location.longitude,
                    latitude: location.latitude
                )
                self.onLocationSelected = onLocationSelected

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

            func pauseEngine() {
                controller?.pauseEngine()
            }

            func resetEngine() {
                controller?.pauseEngine()
                controller?.resetEngine()
            }

            func updateSelectedLocation(_ location: LogLocationDraft) {
                guard
                    selectedLatitude != location.latitude ||
                    selectedLongitude != location.longitude
                else {
                    return
                }

                selectedLatitude = location.latitude
                selectedLongitude = location.longitude
                selectedPosition = MapPoint(
                    longitude: location.longitude,
                    latitude: location.latitude
                )

                guard let mapView = currentMapView else {
                    return
                }

                moveCamera(
                    to: selectedPosition,
                    on: mapView
                )
            }

            @objc func addViews() {
                let mapviewInfo = MapviewInfo(
                    viewName: mapViewName,
                    viewInfoName: "map",
                    defaultPosition: selectedPosition,
                    defaultLevel: 15
                )

                controller?.addView(mapviewInfo)
            }

            @objc func addViewSucceeded(
                _ viewName: String,
                viewInfoName: String
            ) {
                guard let mapView = currentMapView else {
                    return
                }

                mapView.eventDelegate = self

                if let size = viewContainer?.bounds.size {
                    applyMapLayoutIfReady(size)
                }
            }

            @objc func containerDidResized(_ size: CGSize) {
                guard let mapView = currentMapView else {
                        return
                    }

                    mapView.eventDelegate = self // 지도 이벤트를 받음
                    applyMapLayoutIfReady(size) // 카메라를 실제로 움직임
            }

            @objc func addViewFailed(
                _ viewName: String,
                viewInfoName: String
            ) {
                print("Kakao map failed to load: \(viewName)")
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

        @objc func cameraDidStopped(
            kakaoMap: KakaoMap,
            by: MoveBy
        ) {
            guard !shouldIgnoreNextCameraStop else {
                shouldIgnoreNextCameraStop = false
                return
            }

            let centerPoint = CGPoint(
                x: kakaoMap.viewRect.midX,
                y: kakaoMap.viewRect.midY
            )

            let position = kakaoMap.getPosition(centerPoint)
            let coordinate = position.wgsCoord

            guard
                selectedLatitude != coordinate.latitude ||
                    selectedLongitude != coordinate.longitude
            else {
                return
            }

            selectedLatitude = coordinate.latitude
            selectedLongitude = coordinate.longitude
            selectedPosition = position

            onLocationSelected(
                coordinate.latitude,
                coordinate.longitude
            )
        }

        private func moveCamera(
            to position: MapPoint,
            on mapView: KakaoMap
        ) {
            shouldIgnoreNextCameraStop = true

            let cameraUpdate = CameraUpdate.make(
                target: position,
                zoomLevel: 15,
                mapView: mapView
            )

            mapView.moveCamera(cameraUpdate)
        }

        private var currentMapView: KakaoMap? {
            controller?.getView(mapViewName) as? KakaoMap
        }

        private func applyMapLayoutIfReady(_ size: CGSize) {
            guard
                size.width > 0,
                size.height > 0,
                let mapView = currentMapView
            else {
                return
            }

            mapView.viewRect = CGRect(origin: .zero, size: size)

            guard needsInitialCameraMove else {
                return
            }

            moveCamera(
                to: selectedPosition,
                on: mapView
            )
            needsInitialCameraMove = false
        }
    }
}

private struct ClipLocationPickerMapPlaceholder: View {
    var body: some View {
        Color.maplogSurfaceRaised
            .overlay {
                VStack(spacing: MaplogSpacing.small) {
                    Image(systemName: "map")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.maplogTextTertiary)

                    Text("카카오 지도 앱 키가 필요해요")
                        .font(MaplogFont.bodyStrong)
                        .foregroundStyle(Color.maplogTextPrimary)
                }
            }
    }
}
