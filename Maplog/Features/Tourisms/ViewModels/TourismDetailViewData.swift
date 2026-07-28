//
//  TourismDetailViewData.swift
//  Maplog
//
//  Created by 한채림 on 7/26/26.
//

//TourismDetail Domain Model
// → ViewModel이 빈 값 제거·날짜 포맷·한글 제목 결정
// → TourismDetailViewData
// → View는 그리기만 함


import Foundation

struct TourismDetailViewData: Equatable {
    let title: String
    let categoryText: String
    let regionText: String?
    let addressText: String?
    let overviewText: String?
    let heroImageURL: URL?
    let phoneNumber: String?
    let phoneURL: URL?
    let homepageURL: URL?
    let coordinate: TourismDetailCoordinateViewData? // 위도·경도가 둘 다 있을 때만 값이 생김. View는 coordinate != nil일 때만 지도 버튼을 활성화
    let periodText: String? // View는 Date를 몰라도 됨. ViewModel이 "2026. 07. 25. ~ 2026. 07. 30."처럼 완성해 전달
    let statusText: String?
    let informationSections: [TourismDetailInformationSectionViewData] // 한눈에 보기, 장소, 이용 시간, 이용 요금
    let extraInformationRows: [TourismDetailInfoRowViewData]
    let images: [TourismDetailImageViewData]
    let repeatInfoItems: [TourismDetailRepeatInfoViewData]
    let petInformationRows: [TourismDetailInfoRowViewData]
} // 빈 배열이면 해당 섹션 전체를 숨기기 쉬움. 서버의 빈 배열·null을 오류로 다루지 않는 계약과도 맞음

struct TourismDetailCoordinateViewData: Equatable {
    let latitude: Double
    let longitude: Double
}

struct TourismDetailInfoRowViewData: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
}

struct TourismDetailInformationSectionViewData: Identifiable, Equatable {
    let id: String
    let title: String
    let rows: [TourismDetailInfoRowViewData]
}

struct TourismDetailImageViewData: Identifiable, Equatable {
    let id: String
    let imageURL: URL
    let thumbnailURL: URL?
    let title: String?
}

struct TourismDetailRepeatInfoViewData: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String?
    let imageURL: URL?
    let attributeRows: [TourismDetailInfoRowViewData]
}
