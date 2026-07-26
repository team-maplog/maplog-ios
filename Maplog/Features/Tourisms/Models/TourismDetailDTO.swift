//
//  TourismDetailDTO.swift
//  Maplog
//
//  Created by 한채림 on 7/26/26.
//

// APIResponse<TourismDetailDTO>의 바깥 successFlag, code, message는 이미 공통 APIResponse가 담당합니다. 그래서 DTO에는 data 내부만 작성
// 안내 문서가 null이 정상이라고 한 필드는 모두 ?로 선언했습니다. null 때문에 상세 화면 전체가 디코딩 실패하면 안 됨

import Foundation

struct TourismDetailDTO: Decodable {
    let tourismId: Int64
    let category: TourismCategory
    let common: TourismDetailCommonDTO
    let introduction: TourismDetailIntroductionDTO?
    let repeatInfo: [TourismDetailRepeatInfoDTO]
    let images: [TourismDetailImageDTO]
    let petTour: TourismPetTourDTO?
}

struct TourismDetailCommonDTO: Decodable {
    let name: String
    let createdAt: String?
    let modifiedAt: String?
    let tel: String?
    let telName: String?
    let homepageURL: String?
    let thumbnailURL: String?
    let originalImageURL: String?
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

    enum CodingKeys: String, CodingKey {
            case name
            case createdAt
            case modifiedAt
            case tel
            case telName
            case homepageURL = "homepageUrl"
            case thumbnailURL = "thumbnailUrl"
            case originalImageURL = "originalImageUrl"
            case copyrightCode
            case regionCode
            case districtCode
            case classification1
            case classification2
            case classification3
            case region
            case address
            case zipCode
            case longitude
            case latitude
            case mapLevel
            case overview
        }
    }

struct TourismDetailIntroductionDTO: Decodable {
    let type: String?
    let startDate: String?
    let endDate: String?
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
    let homepageURL: String?
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

    enum CodingKeys: String, CodingKey {
        case type
        case startDate
        case endDate
        case openingDate
        case place
        case openingHours
        case closedDays
        case usageFee
        case discountInfo
        case parkingInfo
        case parkingFee
        case contactInfo
        case reservationInfo
        case homepageURL = "homepageUrl"
        case program
        case subEvent
        case sponsor
        case sponsorContact
        case ageLimit
        case experienceGuide
        case experienceAge
        case capacity
        case operatingSeason
        case duration
        case distance
        case schedule
        case theme
        case scale
        case representativeMenu
        case menu
        case seatCount
        case packingInfo
        case smokingInfo
        case kidsFacilityInfo
        case creditCardInfo
        case petInfo
        case babyCarriageInfo
        case extraFields
    }
}

struct TourismDetailRepeatInfoDTO: Decodable {
    let serialNumber: String?
    let title: String?
    let description: String?
    let imageURL: String?
    let attributes: [String: String]?

    enum CodingKeys: String, CodingKey {
        case serialNumber
        case title
        case description
        case imageURL = "imageUrl"
        case attributes
    }
}

struct TourismDetailImageDTO: Decodable {
    let originalURL: String?
    let smallURL: String?
    let name: String?
    let copyrightCode: String?
    let serialNumber: String?

    enum CodingKeys: String, CodingKey {
        case originalURL = "originalUrl"
        case smallURL = "smallUrl"
        case name
        case copyrightCode
        case serialNumber
    }
}

struct TourismPetTourDTO: Decodable {
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
