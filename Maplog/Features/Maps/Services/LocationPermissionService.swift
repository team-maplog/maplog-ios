import CoreLocation
import Foundation

/// 위치 좌표를 읽지 않고, iOS의 "앱 사용 중 위치" 권한만 요청하는 경계입니다.
@MainActor
protocol LocationPermissionService {
    func requestWhenInUseAuthorization() async -> LocationPermissionResult
}

enum LocationPermissionResult: Equatable {
    case authorized
    case denied
    case servicesDisabled
    case unavailable
}

@MainActor
final class CoreLocationPermissionService: NSObject,
    LocationPermissionService {
    private let locationManager = CLLocationManager()
    private var continuations: [
        UUID: CheckedContinuation<LocationPermissionResult, Never>
    ] = [:]
    private var isAuthorizationRequestInFlight = false

    override init() {
        super.init()

        locationManager.delegate = self
    }

    func requestWhenInUseAuthorization() async -> LocationPermissionResult {
        guard CLLocationManager.locationServicesEnabled() else {
            return .servicesDisabled
        }

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .authorized

        case .denied, .restricted:
            return .denied

        case .notDetermined:
            return await withCheckedContinuation { continuation in
                continuations[UUID()] = continuation

                guard !isAuthorizationRequestInFlight else {
                    return
                }

                isAuthorizationRequestInFlight = true
                locationManager.requestWhenInUseAuthorization()
            }

        @unknown default:
            return .unavailable
        }
    }

    private func finishRequests(
        with result: LocationPermissionResult
    ) {
        let pendingContinuations = continuations.values

        continuations.removeAll()
        isAuthorizationRequestInFlight = false

        for continuation in pendingContinuations {
            continuation.resume(returning: result)
        }
    }

    private func result(
        for status: CLAuthorizationStatus
    ) -> LocationPermissionResult? {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return .authorized

        case .denied, .restricted:
            return .denied

        case .notDetermined:
            return nil

        @unknown default:
            return .unavailable
        }
    }
}

extension CoreLocationPermissionService:
    @preconcurrency CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        guard let result = result(
            for: manager.authorizationStatus
        ) else {
            return
        }

        finishRequests(with: result)
    }
}
