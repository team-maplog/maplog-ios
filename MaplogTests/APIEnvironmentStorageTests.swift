import XCTest
@testable import Maplog

final class APIEnvironmentStorageTests: XCTestCase {
    func testKeychainServicesSeparateServersWithTheSameBundleIdentifier() throws {
        let development = try XCTUnwrap(URL(string: "https://dev-api.example.com"))
        let production = try XCTUnwrap(URL(string: "https://api.example.com"))
        let developmentService = KeychainService.serviceName(bundleIdentifier: "com.maplog.app", apiBaseURL: development)
        let productionService = KeychainService.serviceName(bundleIdentifier: "com.maplog.app", apiBaseURL: production)

        XCTAssertNotEqual(developmentService, productionService)
        XCTAssertNotEqual(developmentService, "com.maplog.app.auth")
        XCTAssertNotEqual(productionService, "com.maplog.app.auth")
    }

    func testStorageNamespaceExcludesCredentialsPathQueryAndFragment() throws {
        let url = try XCTUnwrap(URL(string: "https://user:password@api.example.com/api/v1?token=secret#private"))

        XCTAssertEqual(APIConfiguration.storageNamespace(for: url), "https://api.example.com")
    }

    func testDefaultPortsAndHostCaseShareTheSameNamespace() throws {
        let first = try XCTUnwrap(URL(string: "https://API.EXAMPLE.COM:443/"))
        let second = try XCTUnwrap(URL(string: "https://api.example.com"))

        XCTAssertEqual(APIConfiguration.storageNamespace(for: first), APIConfiguration.storageNamespace(for: second))
    }

    func testDifferentSchemesAndNondefaultPortsRemainSeparate() throws {
        let production = try XCTUnwrap(URL(string: "https://api.example.com"))
        let localHTTP = try XCTUnwrap(URL(string: "http://api.example.com"))
        let otherPort = try XCTUnwrap(URL(string: "https://api.example.com:8443"))

        XCTAssertNotEqual(APIConfiguration.storageNamespace(for: production), APIConfiguration.storageNamespace(for: localHTTP))
        XCTAssertNotEqual(APIConfiguration.storageNamespace(for: production), APIConfiguration.storageNamespace(for: otherPort))
    }
}
