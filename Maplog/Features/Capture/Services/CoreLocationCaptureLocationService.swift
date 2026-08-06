//
//  CoreLocationCaptureLocationService.swift
//  Maplog
//
//  Created by 한채림 on 8/6/26.
//

//Core Location 좌표 수신
// → latestLocation에 즉시 좌표 저장
// → 백그라운드처럼 잠깐 장소명 역검색
// → 같은 좌표라면 placeName까지 채워 최신 위치 갱신
//CameraCaptureViewModel
//        ↓
//CoreLocationCaptureLocationService
//        ↓
//CLLocationManager: “위치 권한을 받고 위치를 알려줘”
//        ↓
//CLLocation: 위도·경도 전달
//        ↓
//CLGeocoder: “해운대해수욕장” 같은 장소명으로 변환
//        ↓
//CaptureLocation에 보관


import CoreLocation
import Foundation

@MainActor
final class CoreLocationCaptureLocationService: NSObject, CaptureLocationService {
    private let locationManager = CLLocationManager() // 권한 요청, 위치 추적 시작·중지
        private let geocoder = CLGeocoder() // 좌표를 사람이 읽을 장소명으로 변환

        private(set) var latestLocation: CaptureLocation?

    override init() {
            super.init()

            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 50
        }

    func startUpdatingLocation() {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()

            case .authorizedAlways, .authorizedWhenInUse:
                locationManager.startUpdatingLocation()

            case .denied, .restricted:
                latestLocation = nil

            @unknown default:
                latestLocation = nil
            }
        }

    func stopUpdatingLocation() {
            locationManager.stopUpdatingLocation()
        }

//    관심 장소명(해운대해수욕장 등)
//    → 동/읍/면(죽전동)
//    → 도시명
    private func makePlaceName(
        from location: CLLocation
    ) async -> String? {
        do {
            let placemarks = try await geocoder
                .reverseGeocodeLocation(location)

            guard let placemark = placemarks.first else {
                return nil
            }

            let pointOfInterest = placemark.areasOfInterest?
                .first?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            if let pointOfInterest, !pointOfInterest.isEmpty {
                return pointOfInterest
            }

            let neighborhood = placemark.subLocality?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            if let neighborhood, !neighborhood.isEmpty {
                return neighborhood
            }

            return placemark.locality?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
        } catch {
            return nil
        }
    }
}

extension CoreLocationCaptureLocationService:
    CLLocationManagerDelegate { // 위치가 바뀌었다는 알림을 받는 곳

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()

        case .denied, .restricted:
            latestLocation = nil
            manager.stopUpdatingLocation()

        case .notDetermined:
            break

        @unknown default:
            manager.stopUpdatingLocation()
        }
    }

    func locationManager( // 새 위치가 오면 iOS가 자동으로 호출하는 함수
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { // 위치 여러 개가 들어올 수 있는 배열이고, .last는 그중 가장 최근 위치를 꺼내
            return
        }

        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude

        // 좌표는 즉시 보관한다.
        latestLocation = CaptureLocation(
            latitude: latitude,
            longitude: longitude,
            placeName: nil
        )

        // 장소명은 늦게 도착해도 되므로 촬영을 기다리게 하지 않는다.
        Task { [weak self] in
            guard let self else {
                return
            }

            let placeName = await makePlaceName(from: location)

            guard latestLocation?.latitude == latitude,
                  latestLocation?.longitude == longitude else {
                return
            }

            latestLocation = CaptureLocation(
                latitude: latitude,
                longitude: longitude,
                placeName: placeName
            )
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // 위치를 못 받아도 촬영 자체는 계속 가능해야 한다.
    }
}
