//
//  TourismRepository.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

//백엔드와 앱의 경계
//HomeViewModel은 URL, HTTP, JSON, SUCCESS-002를 모름
//Repository는 SwiftUI, 로딩 스피너, 카드 문구를 모름
//백엔드 JSON이 바뀌면 DTO·Repository만 고치면 됨
//Mock Repository를 주입하면 네트워크 없이 ViewModel 테스트가 가능

enum TourismFetchPolicy: Sendable {
    case cached
    case reload
}

protocol TourismRepository {
    func invalidateCache() async
    func fetchPortraitImage(tourismID: Int64, policy: TourismFetchPolicy) async throws -> TourismPortraitImage?

    func fetchTourisms(
        category: TourismCategory,
        cursor: String?,
        size: Int,
        policy: TourismFetchPolicy
    ) async throws -> TourismPage

    func fetchTourismDetail(
        tourismID: Int64,
        policy: TourismFetchPolicy
    ) async throws -> TourismDetail
}


extension TourismRepository {
    func fetchTourisms(category: TourismCategory, cursor: String?, size: Int) async throws -> TourismPage {
        try await fetchTourisms(category: category, cursor: cursor, size: size, policy: .cached)
    }

    func fetchTourismDetail(tourismID: Int64) async throws -> TourismDetail {
        try await fetchTourismDetail(tourismID: tourismID, policy: .cached)
    }

    func fetchPortraitImage(tourismID: Int64) async throws -> TourismPortraitImage? {
        try await fetchPortraitImage(tourismID: tourismID, policy: .cached)
    }
}
