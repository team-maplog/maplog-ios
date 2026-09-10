//
//  DefaultTourismRepository.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

//- TourismAPIService로 TourismPageDTO 받기
//- TourismDTO의 String 날짜를 Date로 파싱
//- 이미지 문자열을 URL?로 변환
//- DTO의 content를 Domain Model의 tourisms로 변환
//- TourismPage 반환

//서버 언어를 앱 언어로 번역

//TourismPageDTO
//- content
//- String 날짜
//- String 이미지 주소
//
//↓ Repository가 변환
//
//TourismPage
//- tourisms
//- Date 날짜
//- URL? 이미지 주소

//Repository는 구체 클래스가 아니라 TourismAPIService protocol에 의존
//A가 자기 일을 하려면 B가 필요하다면, A는 B에 의존한다.
//DefaultTourismRepository는 서버에서 받은 TourismPageDTO가 있어야 자기 일을 할 수 있음. 그런데 DTO를 가져오는 담당은 API Service
//그래서 Repository는 API Service가 필요
//Repository는 서버 형식의 차이와 불완전한 데이터를 앱 내부에 퍼뜨리지 않도록 막는 경계

import Foundation

final class DefaultTourismRepository: TourismRepository {
    private let apiService: any TourismAPIService
    private let posterCatalog: any VerifiedTourismPosterProviding

    init(apiService: any TourismAPIService, posterCatalog: any VerifiedTourismPosterProviding) {
        self.apiService = apiService
        self.posterCatalog = posterCatalog
    }

    func fetchTourismsWithVerifiedPosters(size: Int) async throws -> [Tourism] {
        guard (1...100).contains(size) else {
            throw APIError.invalidRequest(reason: "size는 1부터 100 사이여야 합니다.")
        }
        var remainingIDs = posterCatalog.tourismIDs
        guard !remainingIDs.isEmpty else { return [] }

        var result: [Tourism] = []
        var cursor: String?
        var visitedCursors = Set<String>()
        while result.count < size {
            try Task.checkCancellation()
            let page = try await fetchTourisms(category: .events, cursor: cursor, size: 100)
            for tourism in page.tourisms where remainingIDs.remove(tourism.id) != nil {
                if tourism.verifiedPosterURL != nil { result.append(tourism) }
                if result.count == size { break }
            }
            guard result.count < size, !remainingIDs.isEmpty, page.hasNext else { break }
            guard let nextCursor = page.nextCursor,
                  visitedCursors.insert(nextCursor).inserted else {
                throw TourismRepositoryError.invalidPagination
            }
            cursor = nextCursor
        }
        return result
    }

    func fetchTourisms(category: TourismCategory, cursor: String?, size: Int) async throws -> TourismPage {
        let pageDTO = try await apiService.fetchTourisms(
            category: category,
            cursor: cursor,
            size: size)

        let tourisms = try pageDTO.content.map { tourismDTO in
            try makeTourism(from: tourismDTO)
        }

        return TourismPage(tourisms: tourisms, hasNext: pageDTO.hasNext, nextCursor: pageDTO.nextCursor)
    }

    func fetchTourismDetail(tourismID: Int64) async throws -> TourismDetail {
        let detailDTO = try await apiService.fetchTourismDetail(tourismID: tourismID)

        return try makeTourismDetail(from: detailDTO)
    }


    private func makeTourism(from dto: TourismDTO) throws -> Tourism {
        let startDate = try date(from: dto.startDate, field: "startDate")
        let endDate = try date(from: dto.endDate, field: "endDate")

        return Tourism(
            id: dto.tourismId,
            name: dto.name,
            region: dto.region,
            address: dto.address,
            thumbnailURL: dto.thumbnailURL.flatMap { URL(string: $0) },
            startDate: startDate,
            endDate: endDate,
            category: dto.category,
            verifiedPosterURL: posterCatalog.posterURL(
                tourismID: dto.tourismId, startDate: startDate, endDate: endDate
            )
            )
    }

    private func makeTourismDetail(from dto: TourismDetailDTO) throws -> TourismDetail {
        let introduction = try dto.introduction.map {
                try makeTourismDetailIntroduction(from: $0)
            }

        return TourismDetail(
                id: dto.tourismId,
                category: dto.category,
                common: makeTourismDetailCommonInfo(from: dto.common),
                introduction: introduction,
                repeatInfo: dto.repeatInfo.map(makeTourismDetailRepeatInfo),
                images: dto.images.map(makeTourismDetailImage), // 서버 배열의 DTO 하나씩을 앱 배열의 Domain Model 하나씩으로 바꿈, 서버가 []를 보내면 앱도 빈 배열을 받고,이미지 섹션을 숨겨야 하는 정상 상태가 됨
                petTour: dto.petTour.map(makeTourismPetTour),
                verifiedPosterURL: posterCatalog.posterURL(
                    tourismID: dto.tourismId,
                    startDate: introduction?.startDate,
                    endDate: introduction?.endDate
                )
            )
    }

    private func makeTourismDetailCommonInfo(from dto: TourismDetailCommonDTO) -> TourismDetailCommonInfo {
        TourismDetailCommonInfo(
                name: dto.name,
                createdAt: dto.createdAt,
                modifiedAt: dto.modifiedAt,
                tel: dto.tel,
                telName: dto.telName,
                homepageURL: dto.homepageURL.flatMap { URL(string: $0) },
                thumbnailURL: dto.thumbnailURL.flatMap { URL(string: $0) },
                originalImageURL: dto.originalImageURL.flatMap { URL(string: $0) },
                copyrightCode: dto.copyrightCode,
                regionCode: dto.regionCode,
                districtCode: dto.districtCode,
                classification1: dto.classification1,
                classification2: dto.classification2,
                classification3: dto.classification3,
                region: dto.region,
                address: dto.address,
                zipCode: dto.zipCode,
                longitude: dto.longitude,
                latitude: dto.latitude,
                mapLevel: dto.mapLevel,
                overview: dto.overview
            )
    }

    private func makeTourismDetailIntroduction(from dto: TourismDetailIntroductionDTO) throws -> TourismDetailIntroduction {
        TourismDetailIntroduction(
                type: dto.type,
                startDate: try date(from: dto.startDate, field: "startDate"),
                endDate: try date(from: dto.endDate, field: "endDate"),
                openingDate: dto.openingDate,
                place: dto.place,
                openingHours: dto.openingHours,
                closedDays: dto.closedDays,
                usageFee: dto.usageFee,
                discountInfo: dto.discountInfo,
                parkingInfo: dto.parkingInfo,
                parkingFee: dto.parkingFee,
                contactInfo: dto.contactInfo,
                reservationInfo: dto.reservationInfo,
                homepageURL: dto.homepageURL.flatMap { URL(string: $0) },
                program: dto.program,
                subEvent: dto.subEvent,
                sponsor: dto.sponsor,
                sponsorContact: dto.sponsorContact,
                ageLimit: dto.ageLimit,
                experienceGuide: dto.experienceGuide,
                experienceAge: dto.experienceAge,
                capacity: dto.capacity,
                operatingSeason: dto.operatingSeason,
                duration: dto.duration,
                distance: dto.distance,
                schedule: dto.schedule,
                theme: dto.theme,
                scale: dto.scale,
                representativeMenu: dto.representativeMenu,
                menu: dto.menu,
                seatCount: dto.seatCount,
                packingInfo: dto.packingInfo,
                smokingInfo: dto.smokingInfo,
                kidsFacilityInfo: dto.kidsFacilityInfo,
                creditCardInfo: dto.creditCardInfo,
                petInfo: dto.petInfo,
                babyCarriageInfo: dto.babyCarriageInfo,
                extraFields: dto.extraFields
            )
    }

    private func makeTourismDetailRepeatInfo(from dto: TourismDetailRepeatInfoDTO) -> TourismDetailRepeatInfo {
        TourismDetailRepeatInfo(
                serialNumber: dto.serialNumber,
                title: dto.title,
                description: dto.description,
                imageURL: dto.imageURL.flatMap { URL(string: $0) },
                attributes: dto.attributes
            )
    }

    private func makeTourismDetailImage(
        from dto: TourismDetailImageDTO
    ) -> TourismDetailImage {
        TourismDetailImage(
            originalURL: dto.originalURL.flatMap { URL(string: $0) },
            smallURL: dto.smallURL.flatMap { URL(string: $0) },
            name: dto.name,
            copyrightCode: dto.copyrightCode,
            serialNumber: dto.serialNumber
        )
    }

    private func makeTourismPetTour(
        from dto: TourismPetTourDTO
    ) -> TourismPetTour {
        TourismPetTour(
            accidentRisk: dto.accidentRisk,
            accompanimentType: dto.accompanimentType,
            relatedFacility: dto.relatedFacility,
            relatedSupplies: dto.relatedSupplies,
            otherInfo: dto.otherInfo,
            relatedPurchaseSupplies: dto.relatedPurchaseSupplies,
            accompanimentPossibleCapacity: dto.accompanimentPossibleCapacity,
            relatedRentalSupplies: dto.relatedRentalSupplies,
            requiredItems: dto.requiredItems
        )
    }

    private func date(from value: String?, field: String) throws -> Date? {
        guard let value else {
            return nil
        }

        guard let date = parseDate(value) else {
            throw TourismRepositoryError.invalidDate(
                field: field,
                value: value
            )
        }

        return date
    }

    private func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.date(from: value)
    }



}

//Repository
//1. Service에게 DTO 요청
//2. DTO의 content 각각을 Tourism으로 변환
//3. TourismPage로 묶어서 ViewModel에 반환
