//
//  TourismDetail.swift
//  Maplog
//
//  Created by 한채림 on 7/26/26.
//

//DTO
//- 서버 JSON 형태
//- "thumbnailUrl": String?
//- "2026-07-25": String?
//
//Domain Model
//- 앱 내부 형태
//- thumbnailURL: URL?
//- startDate: Date?

import Foundation

struct TourismDetail: Equatable {
    let id: Int64
    let category: TourismCategory
    let common: TourismDetailCommonInfo
    let introduction: TourismDetailIntroduction?
    let repeatInfo: [TourismDetailRepeatInfo]
    let images: [TourismDetailImage]
    let petTour: TourismPetTour?

    /// 홈과 상세에서 동일한 대표 원본을 선택한다.
    var representativeImageURL: URL? {
        common.originalImageURL
            ?? images.lazy.compactMap { $0.originalURL ?? $0.smallURL }.first
            ?? common.thumbnailURL
    }
}

struct TourismDetailCommonInfo: Equatable {
    let name: String
    let createdAt: String?
    let modifiedAt: String?
    let tel: String?
    let telName: String?
    let homepageURL: URL?
    let thumbnailURL: URL?
    let originalImageURL: URL?
    let copyrightCode: String?
    let regionCode: String?
    let districtCode: String?
    let classification1: String?
    let classification2: String?
    let classification3: String?
    let region: String?
    let address: String?
    let zipCode: String?
    let longitude: Double?
    let latitude: Double?
    let mapLevel: String?
    let overview: String?
}

struct TourismDetailIntroduction: Equatable {
    let type: String?
    let startDate: Date?
    let endDate: Date?
    let openingDate: String?
    let place: String?
    let openingHours: String?
    let closedDays: String?
    let usageFee: String?
    let discountInfo: String?
    let parkingInfo: String?
    let parkingFee: String?
    let contactInfo: String?
    let reservationInfo: String?
    let homepageURL: URL?
    let program: String?
    let subEvent: String?
    let sponsor: String?
    let sponsorContact: String?
    let ageLimit: String?
    let experienceGuide: String?
    let experienceAge: String?
    let capacity: String?
    let operatingSeason: String?
    let duration: String?
    let distance: String?
    let schedule: String?
    let theme: String?
    let scale: String?
    let representativeMenu: String?
    let menu: String?
    let seatCount: String?
    let packingInfo: String?
    let smokingInfo: String?
    let kidsFacilityInfo: String?
    let creditCardInfo: String?
    let petInfo: String?
    let babyCarriageInfo: String?
    let extraFields: [String: String]?
}

struct TourismDetailRepeatInfo: Equatable {
    let serialNumber: String?
    let title: String?
    let description: String?
    let imageURL: URL?
    let attributes: [String: String]?
}

struct TourismDetailImage: Equatable {
    let originalURL: URL?
    let smallURL: URL?
    let name: String?
    let copyrightCode: String?
    let serialNumber: String?
}

struct TourismPetTour: Equatable {
    let accidentRisk: String?
    let accompanimentType: String?
    let relatedFacility: String?
    let relatedSupplies: String?
    let otherInfo: String?
    let relatedPurchaseSupplies: String?
    let accompanimentPossibleCapacity: String?
    let relatedRentalSupplies: String?
    let requiredItems: String?
}
