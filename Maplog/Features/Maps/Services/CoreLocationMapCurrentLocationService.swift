//
//  CoreLocationMapCurrentLocationService.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
//

import CoreLocation
import Foundation

@MainActor
final class CoreLocationMapCurrentLocationService: NSObject,
    MapCurrentLocationService {
    private let locationManager = CLLocationManager()
    private var continuations: [UUID: CheckedContinuation<MapCoordinate, Error>] = [:]
    private var isRequestInFlight = false

    override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestCurrentLocation() async throws -> MapCoordinate {
        guard CLLocationManager.locationServicesEnabled() else {
            throw MapCurrentLocationError.servicesDisabled
        }

        return try await withCheckedThrowingContinuation { continuation in
            continuations[UUID()] = continuation

            guard !isRequestInFlight else {
                return
            }

            isRequestInFlight = true
            beginLocationRequest()
        }
    }

    private func beginLocationRequest() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()

        case .denied, .restricted:
            finishRequests(
                with: .failure(
                    MapCurrentLocationError.authorizationDenied
                )
            )

        @unknown default:
            finishRequests(
                with: .failure(
                    MapCurrentLocationError.unavailable
                )
            )
        }
    }

    private func finishRequests(
        with result: Result<MapCoordinate, Error>
    ) {
        let pendingContinuations = continuations.values

        continuations.removeAll()
        isRequestInFlight = false

        for continuation in pendingContinuations {
            switch result {
            case let .success(coordinate):
                continuation.resume(returning: coordinate)

            case let .failure(error):
                continuation.resume(throwing: error)
            }
        }
    }
}

extension CoreLocationMapCurrentLocationService:
    @preconcurrency CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        guard isRequestInFlight else {
            return
        }

        beginLocationRequest()
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            finishRequests(
                with: .failure(MapCurrentLocationError.unavailable)
            )
            return
        }

        finishRequests(
            with: .success(
                MapCoordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            )
        )
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        finishRequests(
            with: .failure(MapCurrentLocationError.unavailable)
        )
    }
}
