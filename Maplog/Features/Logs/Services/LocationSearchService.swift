import MapKit

protocol LocationSearchService {
    func search(query: String, near location: LogLocationDraft) async throws -> [LogLocationDraft]
}

/// 이 선택 화면의 지도와 검색을 같은 MapKit 데이터로 제공합니다.
final class MapKitLocationSearchService: LocationSearchService {
    func search(query: String, near location: LogLocationDraft) async throws -> [LogLocationDraft] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            latitudinalMeters: 20_000,
            longitudinalMeters: 20_000
        )
        let search = MKLocalSearch(request: request)
        let response = try await withTaskCancellationHandler {
            try await search.start()
        } onCancel: {
            search.cancel()
        }
        try Task.checkCancellation()
        return response.mapItems.map { item in
            LogLocationDraft(
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude,
                name: item.name,
                address: item.placemark.title
            )
        }
    }
}
