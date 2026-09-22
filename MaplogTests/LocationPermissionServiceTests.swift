import CoreLocation
import XCTest
@testable import Maplog

@MainActor
final class LocationPermissionServiceTests: XCTestCase {
    func testOnlyUndeterminedPermissionNeedsLoginExplanation() {
        let manager = PermissionLocationManagerStub()
        let service = CoreLocationPermissionService(locationManager: manager)
        for status: CLAuthorizationStatus in [.notDetermined, .authorizedAlways, .authorizedWhenInUse, .denied, .restricted] {
            manager.status = status
            XCTAssertEqual(service.needsAuthorizationRequest, status == .notDetermined)
        }
        XCTAssertEqual(manager.requestCount, 0, "권한 확인 자체가 시스템 팝업을 요청하면 안 된다.")
    }

    func testPermissionChangesInSettingsAreReadAgain() {
        let manager = PermissionLocationManagerStub()
        let service = CoreLocationPermissionService(locationManager: manager)
        XCTAssertTrue(service.needsAuthorizationRequest)
        manager.status = .authorizedWhenInUse
        XCTAssertFalse(service.needsAuthorizationRequest)
        manager.status = .denied
        XCTAssertFalse(service.needsAuthorizationRequest)
        manager.status = .notDetermined
        XCTAssertTrue(service.needsAuthorizationRequest)
    }
}

private final class PermissionLocationManagerStub: CLLocationManager {
    var status: CLAuthorizationStatus = .notDetermined
    var requestCount = 0
    override var authorizationStatus: CLAuthorizationStatus { status }
    override func requestWhenInUseAuthorization() { requestCount += 1 }
}
