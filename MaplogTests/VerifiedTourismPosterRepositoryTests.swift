import XCTest
@testable import Maplog

final class VerifiedTourismPosterRepositoryTests: XCTestCase {
    private let posterURL = URL(string: "https://example.invalid/verified-poster.jpg")!

    func testEmptyCatalogDoesNotFetchUnverifiedTourisms() async throws {
        let service = PosterAPIStub()
        let repository = DefaultTourismRepository(apiService: service, posterCatalog: LocalVerifiedTourismPosterCatalog(posters: []))
        let result = try await repository.fetchTourismsWithVerifiedPosters(size: 10)
        XCTAssertTrue(result.isEmpty)
        XCTAssertTrue(service.cursors.isEmpty)
    }

    func testFindsVerifiedPosterOnNextPageAndPreservesFullListing() async throws {
        let service = PosterAPIStub()
        service.pages = [
            TourismPageDTO(content: [item(id: 2)], hasNext: true, nextCursor: "next"),
            TourismPageDTO(content: [item(id: 1)], hasNext: false, nextCursor: nil)
        ]
        let repository = makeRepository(service)
        let result = try await repository.fetchTourismsWithVerifiedPosters(size: 10)
        XCTAssertEqual(result.map(\.id), [1])
        XCTAssertEqual(result.first?.verifiedPosterURL, posterURL)
        XCTAssertEqual(service.cursors, [nil, "next"])

        service.cursors = []
        let fullList = try await repository.fetchTourisms(category: .events, cursor: nil, size: 10)
        XCTAssertEqual(fullList.tourisms.map(\.id), [2])
        XCTAssertNil(fullList.tourisms.first?.verifiedPosterURL)
    }

    func testHomeAndDetailUseSameCatalogPoster() async throws {
        let service = PosterAPIStub()
        service.pages = [TourismPageDTO(content: [item(id: 1)], hasNext: false, nextCursor: nil)]
        let repository = makeRepository(service)
        let home = try await repository.fetchTourismsWithVerifiedPosters(size: 10)
        let detail = try await repository.fetchTourismDetail(tourismID: 1)
        XCTAssertEqual(home.first?.verifiedPosterURL, detail.verifiedPosterURL)
        XCTAssertEqual(detail.representativeImageURL, posterURL)
    }

    func testDifferentEventDatesDoNotReuseVerifiedPoster() async throws {
        let service = PosterAPIStub()
        service.pages = [TourismPageDTO(content: [item(id: 1, year: "2027")], hasNext: false, nextCursor: nil)]
        let result = try await makeRepository(service).fetchTourismsWithVerifiedPosters(size: 10)
        XCTAssertTrue(result.isEmpty)
    }

    func testAmbiguousCatalogEntryIsNotTreatedAsVerified() async throws {
        let service = PosterAPIStub()
        service.pages = [TourismPageDTO(content: [item(id: 1)], hasNext: false, nextCursor: nil)]
        let catalog = LocalVerifiedTourismPosterCatalog(posters: [entry(), entry()])
        let repository = DefaultTourismRepository(apiService: service, posterCatalog: catalog)
        let result = try await repository.fetchTourismsWithVerifiedPosters(size: 10)
        XCTAssertTrue(result.isEmpty)
    }

    func testRepeatedCursorStopsInsteadOfLooping() async throws {
        let service = PosterAPIStub()
        service.pages = Array(repeating: TourismPageDTO(content: [item(id: 2)], hasNext: true, nextCursor: "same"), count: 2)
        do {
            _ = try await makeRepository(service).fetchTourismsWithVerifiedPosters(size: 10)
            XCTFail("Expected invalid pagination")
        } catch TourismRepositoryError.invalidPagination {
            XCTAssertEqual(service.cursors.count, 2)
        }
    }

    private func makeRepository(_ service: PosterAPIStub) -> DefaultTourismRepository {
        DefaultTourismRepository(apiService: service, posterCatalog: LocalVerifiedTourismPosterCatalog(posters: [entry()]))
    }

    private func entry() -> VerifiedTourismPoster {
        VerifiedTourismPoster(tourismID: 1, imageURL: posterURL, eventStartDate: "2026-09-09", eventEndDate: "2026-09-10")
    }

    private func item(id: Int64, year: String = "2026") -> TourismDTO {
        TourismDTO(tourismId: id, name: "축제", region: "서울", address: nil,
                   thumbnailURL: "https://example.invalid/ordinary-photo.jpg",
                   startDate: "\(year)-09-09", endDate: "\(year)-09-10", category: .events)
    }
}

private final class PosterAPIStub: TourismAPIService {
    var cursors: [String?] = []
    var pages: [TourismPageDTO] = []
    func fetchTourisms(category: TourismCategory, cursor: String?, size: Int) async throws -> TourismPageDTO {
        let page = pages[cursors.count]
        cursors.append(cursor)
        return page
    }
    func fetchTourismDetail(tourismID: Int64) async throws -> TourismDetailDTO {
        let json = #"{"tourismId":1,"category":"EVENTS","common":{"name":"축제","originalImageUrl":"https://example.invalid/ordinary-photo.jpg"},"introduction":{"startDate":"2026-09-09","endDate":"2026-09-10"},"repeatInfo":[],"images":[],"petTour":null}"#
        return try JSONDecoder().decode(TourismDetailDTO.self, from: Data(json.utf8))
    }
}
