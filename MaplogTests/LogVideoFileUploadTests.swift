import XCTest
@testable import Maplog

@MainActor
final class LogVideoFileUploadTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        UploadURLProtocol.handler = nil
        try FileManager.default.removeItem(at: directory)
    }

    func testMultipartPreservesPayloadAcrossMultipleChunksAndWireContract() async throws {
        let payload = Data((0..<200_000).map { UInt8($0 % 251) })
        let source = directory.appendingPathComponent("clip.mov")
        try payload.write(to: source)
        let builder = LogVideoUploadFileBuilder(temporaryDirectory: directory)
        let body = try await builder.makeMultipartFile(from: source, boundary: "test-boundary")
        var expected = Data("--test-boundary\r\nContent-Disposition: form-data; name=\"file\"; filename=\"clip.mov\"\r\nContent-Type: video/quicktime\r\n\r\n".utf8)
        expected.append(payload)
        expected.append(Data("\r\n--test-boundary--\r\n".utf8))
        XCTAssertEqual(try Data(contentsOf: body), expected)
        XCTAssertEqual(try Data(contentsOf: source), payload)
    }

    func testMissingSourceDoesNotLeaveMultipartFile() async throws {
        let builder = LogVideoUploadFileBuilder(temporaryDirectory: directory)
        do {
            _ = try await builder.makeMultipartFile(from: directory.appendingPathComponent("missing.mov"), boundary: "test")
            XCTFail("Expected missing file error")
        } catch { }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testCancelledBuildDoesNotLeaveMultipartFile() async throws {
        let source = directory.appendingPathComponent("clip.mov")
        try Data([1, 2, 3]).write(to: source)
        let builder = LogVideoUploadFileBuilder(temporaryDirectory: directory)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await builder.makeMultipartFile(from: source, boundary: "test")
        }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch is CancellationError { }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["clip.mov"])
    }

    func testUploadKeepsSameBodyForAuthenticationRetryThenCleansIt() async throws {
        let session = GenerationSession()
        let builder = RecordingUploadBuilder(directory: directory)
        let source = directory.appendingPathComponent("clip.mov")
        try Data([1, 2, 3]).write(to: source)
        let service = makeService(session: session, builder: builder)
        var attempts = 0
        var initialBody: Data?
        UploadURLProtocol.handler = { instance in
            Task { @MainActor in
                attempts += 1
                let bodyURL = await builder.bodyURL!
                let body = try Data(contentsOf: bodyURL)
                XCTAssertEqual(instance.request.httpMethod, "POST")
                XCTAssertEqual(instance.request.url?.path, "/api/v1/files")
                XCTAssertEqual(URLComponents(url: instance.request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "LOG_VIDEO")
                XCTAssertTrue(instance.request.value(forHTTPHeaderField: "Content-Type")!.hasPrefix("multipart/form-data; boundary="))
                if attempts == 1 {
                    initialBody = body
                    instance.reply(status: 401, body: "{\"successFlag\":false,\"code\":\"EXPIRED_TOKEN\",\"message\":\"expired\",\"data\":null}")
                } else {
                    XCTAssertEqual(body, initialBody)
                    XCTAssertEqual(instance.request.value(forHTTPHeaderField: "Authorization"), "Bearer rotated")
                    instance.reply(status: 200, body: "{\"successFlag\":true,\"code\":\"SUCCESS-001\",\"message\":\"ok\",\"data\":{\"fileId\":7}}")
                }
            }
        }
        let response = try await service.uploadLogVideo(fileURL: source)
        XCTAssertEqual(response.fileId, 7)
        XCTAssertEqual(attempts, 2)
        let bodyURL = await builder.bodyURL!
        XCTAssertFalse(FileManager.default.fileExists(atPath: bodyURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        let builds = await builder.builds
        XCTAssertEqual(builds, 1)
    }

    func testFailedUploadCleansBodyAndKeepsSource() async throws {
        let builder = RecordingUploadBuilder(directory: directory)
        let source = directory.appendingPathComponent("clip.mov")
        try Data([1, 2, 3]).write(to: source)
        let service = makeService(session: GenerationSession(), builder: builder)
        UploadURLProtocol.handler = { $0.reply(status: 500, body: "{\"successFlag\":false,\"code\":\"COMMON-001\",\"message\":\"error\",\"data\":null}") }
        do { _ = try await service.uploadLogVideo(fileURL: source); XCTFail("Expected server error") }
        catch APIError.server { }
        let bodyURL = await builder.bodyURL!
        XCTAssertFalse(FileManager.default.fileExists(atPath: bodyURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testCancelledUploadCleansBodyAndKeepsSource() async throws {
        let builder = RecordingUploadBuilder(directory: directory)
        let source = directory.appendingPathComponent("clip.mov")
        try Data([1, 2, 3]).write(to: source)
        let service = makeService(session: GenerationSession(), builder: builder)
        let started = expectation(description: "upload started")
        UploadURLProtocol.handler = { _ in started.fulfill() }
        let task = Task { try await service.uploadLogVideo(fileURL: source) }
        await fulfillment(of: [started], timeout: 3)
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch is CancellationError { }
        let bodyURL = await builder.bodyURL!
        XCTAssertFalse(FileManager.default.fileExists(atPath: bodyURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    private func makeService(session: GenerationSession, builder: RecordingUploadBuilder) -> DefaultLogPublishingAPIService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UploadURLProtocol.self]
        let client = AuthenticatedAPIClient(apiClient: APIClient(session: URLSession(configuration: configuration)), authSession: session, tokenRefresher: UploadRefreshSpy(session: session))
        return DefaultLogPublishingAPIService(authenticatedAPIClient: client, uploadFileBuilder: builder)
    }
}

private actor RecordingUploadBuilder: LogVideoUploadFileBuilding {
    let builder: LogVideoUploadFileBuilder
    private(set) var bodyURL: URL?
    private(set) var builds = 0
    init(directory: URL) { builder = LogVideoUploadFileBuilder(temporaryDirectory: directory) }
    func makeMultipartFile(from videoURL: URL, boundary: String) async throws -> URL {
        builds += 1
        let result = try await builder.makeMultipartFile(from: videoURL, boundary: boundary)
        bodyURL = result
        return result
    }
}

@MainActor
private final class UploadRefreshSpy: AccessTokenRefreshing {
    let session: GenerationSession
    init(session: GenerationSession) { self.session = session }
    func refreshAccessToken() async throws {
        try session.replaceTokens(with: .init(accessToken: "rotated", refreshToken: "refresh-rotated"))
    }
}

private final class UploadURLProtocol: URLProtocol {
    static var handler: ((UploadURLProtocol) -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.handler?(self) }
    override func stopLoading() { }
    func reply(status: Int, body: String) {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
