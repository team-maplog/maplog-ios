import ImageIO
import UIKit
import XCTest
@testable import Maplog

@MainActor
final class TourismPortraitImageTests: XCTestCase {
    func testLoadsDetailOriginalAndPreservesImageDimensions() async throws {
        let service = PortraitAPIStub()
        let loader = PortraitImageLoaderStub()
        let repository = DefaultTourismRepository(apiService: service, imageDataLoader: loader)
        let result = try await repository.fetchPortraitImage(tourismID: 1)
        let image = try XCTUnwrap(result)
        XCTAssertEqual(image.url.absoluteString, service.originalURL)
        XCTAssertEqual(loader.requestedURLs, [image.url])
        XCTAssertEqual(image.width, 200)
        XCTAssertEqual(image.height, 300)
        XCTAssertEqual(image.data, loader.data)
    }

    func testLandscapeAndSquareAreExcluded() async throws {
        for size in [CGSize(width: 300, height: 200), CGSize(width: 200, height: 200)] {
            let loader = PortraitImageLoaderStub()
            loader.data = Self.imageData(size: size)
            let repository = DefaultTourismRepository(apiService: PortraitAPIStub(), imageDataLoader: loader)
            let image = try await repository.fetchPortraitImage(tourismID: 1)
            XCTAssertNil(image)
        }
    }

    func testMissingOriginalDoesNotFallBackToThumbnailOrRelatedImage() async throws {
        let service = PortraitAPIStub()
        service.originalURL = nil
        let loader = PortraitImageLoaderStub()
        let repository = DefaultTourismRepository(apiService: service, imageDataLoader: loader)
        let image = try await repository.fetchPortraitImage(tourismID: 1)
        XCTAssertNil(image)
        XCTAssertTrue(loader.requestedURLs.isEmpty)
    }

    func testUndecodableImageIsExcluded() async throws {
        let loader = PortraitImageLoaderStub()
        loader.data = Data("not an image".utf8)
        let repository = DefaultTourismRepository(apiService: PortraitAPIStub(), imageDataLoader: loader)
        let image = try await repository.fetchPortraitImage(tourismID: 1)
        XCTAssertNil(image)
    }

    func testExifRotationUsesDisplayedOrientation() async throws {
        let raw = Self.imageData(size: CGSize(width: 300, height: 200))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(raw as CFData, nil))
        let cgImage = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let loader = PortraitImageLoaderStub()
        loader.data = data as Data
        let repository = DefaultTourismRepository(apiService: PortraitAPIStub(), imageDataLoader: loader)
        let result = try await repository.fetchPortraitImage(tourismID: 1)
        let image = try XCTUnwrap(result)
        XCTAssertEqual(image.width, 200)
        XCTAssertEqual(image.height, 300)
    }

    static func imageData(size: CGSize) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            UIColor.systemPurple.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

private final class PortraitAPIStub: TourismAPIService {
    var originalURL: String? = "https://example.invalid/original.jpg"
    func fetchTourisms(category: TourismCategory, cursor: String?, size: Int) async throws -> TourismPageDTO {
        fatalError("Unused")
    }
    func fetchTourismDetail(tourismID: Int64) async throws -> TourismDetailDTO {
        let json: [String: Any] = [
            "tourismId": tourismID, "category": "EVENTS",
            "common": ["name": "축제", "originalImageUrl": originalURL as Any? ?? NSNull(),
                       "thumbnailUrl": "https://example.invalid/thumbnail.jpg"],
            "repeatInfo": [], "images": [["originalUrl": "https://example.invalid/related.jpg"]]
        ]
        return try JSONDecoder().decode(TourismDetailDTO.self, from: JSONSerialization.data(withJSONObject: json))
    }
}

@MainActor
private final class PortraitImageLoaderStub: ImageDataLoading {
    var data = TourismPortraitImageTests.imageData(size: CGSize(width: 200, height: 300))
    var requestedURLs: [URL] = []
    func imageData(from url: URL, cacheKey: String, targetSize: MaplogImageTargetSize) async throws -> Data {
        requestedURLs.append(url)
        return data
    }
}
