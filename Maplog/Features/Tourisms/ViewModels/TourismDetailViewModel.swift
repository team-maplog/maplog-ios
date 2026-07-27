//
//  TourismDetailViewModel.swift
//  Maplog
//
//  Created by 한채림 on 7/26/26.
//
//View는 load()만 호출
//ViewModel은 Repository에 요청
//성공하면 Domain Model을 ViewData로 변환
//실패하면 TourismDetailErrorPolicy로 화면 문구·행동 결정
//View는 .loading / .content / .failed만 그림


import Foundation

@MainActor
final class TourismDetailViewModel: ObservableObject {
    @Published private(set) var state: TourismDetailState = .idle

    private let tourismID: Int64
    private let tourismRepository: any TourismRepository

    private let periodDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy. MM. dd."
        return formatter
    }()

    init(
        tourismID: Int64,
        tourismRepository: any TourismRepository
    ) {
        self.tourismID = tourismID
        self.tourismRepository = tourismRepository
    }

    func load() async {
        guard state == .idle else {
            return
        }

        state = .loading

        do {
            let detail = try await tourismRepository.fetchTourismDetail(tourismID: tourismID)

            guard !Task.isCancelled else {
                state = .idle
                return
            }

            state = .content(makeViewData(from: detail))
        } catch is CancellationError {
            state = .idle
        } catch {
            guard !Task.isCancelled else {
                state = .idle
                return
            }

            state = .failed(TourismDetailErrorPolicy.presentation(for: error))
        }
    }

    func retry() async {
        guard case .failed = state else {
            return
        }

        state = .idle
        await load()
    }

    private func makeViewData(from detail: TourismDetail) -> TourismDetailViewData {
        let imageItems = makeImageItems(from: detail.images)
        let heroImageURL = detail.common.originalImageURL // 원본 대표 이미지
            ?? imageItems.first?.imageURL // 상세 이미지 원본
            ?? detail.common.thumbnailURL // 썸네일
        let phoneNumber = nonEmpty(detail.common.tel)
        let overviewText = nonEmpty(detail.common.overview)
        let informationRows = makeInformationRows(from: detail.introduction)
        
        return TourismDetailViewData(
            title: detail.common.name,
            categoryText: categoryText(for: detail.category),
            regionText: nonEmpty(detail.common.region),
            addressText: nonEmpty(detail.common.address),
            overviewText: overviewText,
            heroImageURL: heroImageURL,
            phoneNumber: nonEmpty(detail.common.tel),
            phoneURL: makeTelephoneURL(from: phoneNumber),
            homepageURL: detail.common.homepageURL
            ?? detail.introduction?.homepageURL,
            coordinate: makeCoordinate(
                latitude: detail.common.latitude,
                longitude: detail.common.longitude
            ),
            periodText: periodText(from: detail.introduction),
            informationSections: makeInformationSections(from: informationRows),
            extraInformationRows: makeExtraInformationRows(
                from: detail.introduction
            ),
            images: imageItems,
            repeatInfoItems: makeRepeatInfoItems(
                from: detail.repeatInfo,
                overviewText: overviewText
            ),
            petInformationRows: makePetInformationRows(
                from: detail.petTour
            )
        )
    }
    private func categoryText(
        for category: TourismCategory
    ) -> String {
        switch category {
        case .all:
            return "전체 관광"
        case .events:
            return "행사 전체"
        case .festival:
            return "축제"
        case .performance:
            return "공연"
        case .event:
            return "행사"
        case .recommendedCourse:
            return "추천 코스"
        case .experienceTourism:
            return "체험 관광"
        case .historyTourism:
            return "역사 관광"
        case .leisureSports:
            return "레저·스포츠"
        case .natureTourism:
            return "자연 관광"
        case .culturalTourism:
            return "문화 관광"
        }
    }

    private func makeCoordinate(latitude: Double?, longitude: Double?) -> TourismDetailCoordinateViewData? {
        guard let latitude, let longitude else {
            return nil
        }

        return TourismDetailCoordinateViewData(latitude: latitude, longitude: longitude)
    }

    private func periodText(
        from introduction: TourismDetailIntroduction?
    ) -> String? {
        guard let introduction else {
            return nil
        }

        switch (introduction.startDate, introduction.endDate) {
        case let (startDate?, endDate?):
            return "\(periodDateFormatter.string(from: startDate)) ~ \(periodDateFormatter.string(from: endDate))"

        case let (startDate?, nil):
            return "시작일 \(periodDateFormatter.string(from: startDate))"

        case let (nil, endDate?):
            return "종료일 \(periodDateFormatter.string(from: endDate))"

        case (nil, nil):
            return nil
        }
    }

    private func makeInformationRows(
        from introduction: TourismDetailIntroduction?
    ) -> [TourismDetailInfoRowViewData] {
        guard let introduction else {
            return []
        }

        return [
        makeInfoRow("place", title: "장소", value: introduction.place),
        makeInfoRow("openingHours", title: "이용 시간", value: introduction.openingHours),
        makeInfoRow("closedDays", title: "휴무일", value: introduction.closedDays),
        makeInfoRow("usageFee", title: "이용 요금", value: introduction.usageFee),
        makeInfoRow("discountInfo", title: "할인 정보", value: introduction.discountInfo),
        makeInfoRow("parkingInfo", title: "주차 안내", value: introduction.parkingInfo),
        makeInfoRow("parkingFee", title: "주차 요금", value: introduction.parkingFee),
        makeInfoRow("contactInfo", title: "문의", value: introduction.contactInfo),
        makeInfoRow("reservationInfo", title: "예약", value: introduction.reservationInfo),
        makeInfoRow("program", title: "프로그램", value: introduction.program),
        makeInfoRow("subEvent", title: "부대 행사", value: introduction.subEvent),
        makeInfoRow("sponsor", title: "주최", value: introduction.sponsor),
        makeInfoRow("sponsorContact", title: "주최 문의", value: introduction.sponsorContact),
        makeInfoRow("experienceGuide", title: "체험 안내", value: introduction.experienceGuide),
        makeInfoRow("experienceAge", title: "체험 가능 연령", value: introduction.experienceAge),
        makeInfoRow("ageLimit", title: "관람 연령", value: introduction.ageLimit),
        makeInfoRow("operatingSeason", title: "운영 기간", value: introduction.operatingSeason),
        makeInfoRow("duration", title: "소요 시간", value: introduction.duration),
        makeInfoRow("distance", title: "거리", value: introduction.distance),
        makeInfoRow("schedule", title: "일정", value: introduction.schedule),
        makeInfoRow("theme", title: "테마", value: introduction.theme),
        makeInfoRow("representativeMenu", title: "대표 메뉴", value: introduction.representativeMenu),
        makeInfoRow("menu", title: "메뉴", value: introduction.menu),
        makeInfoRow("seatCount", title: "좌석", value: introduction.seatCount),
        makeInfoRow("packingInfo", title: "포장 안내", value: introduction.packingInfo),
        makeInfoRow("smokingInfo", title: "흡연 안내", value: introduction.smokingInfo),
        makeInfoRow("kidsFacilityInfo", title: "어린이 시설", value: introduction.kidsFacilityInfo),
        makeInfoRow("creditCardInfo", title: "카드 사용", value: introduction.creditCardInfo),
        makeInfoRow("petInfo", title: "반려동물 안내", value: introduction.petInfo),
        makeInfoRow("babyCarriageInfo", title: "유모차 안내", value: introduction.babyCarriageInfo)
        ]
            .compactMap { $0 }
    }
    
    private func makeInformationSections(
        from rows: [TourismDetailInfoRowViewData]
    ) -> [TourismDetailInformationSectionViewData] {
        [
            makeInformationSection(
                id: "quick",
                title: "한눈에 보기",
                rowIDs: ["place", "openingHours", "usageFee"],
                sourceRows: rows
            ),
            makeInformationSection(
                id: "visit",
                title: "방문 전 확인",
                rowIDs: [
                    "closedDays",
                    "discountInfo",
                    "parkingInfo",
                    "parkingFee",
                    "reservationInfo",
                    "contactInfo",
                    "ageLimit",
                    "operatingSeason"
                ],
                sourceRows: rows
            ),
            makeInformationSection(
                id: "program",
                title: "프로그램",
                rowIDs: [
                    "program",
                    "subEvent",
                    "experienceGuide",
                    "experienceAge",
                    "duration",
                    "distance",
                    "schedule",
                    "theme"
                ],
                sourceRows: rows
            ),
            makeInformationSection(
                id: "food",
                title: "음식점 정보",
                rowIDs: [
                    "representativeMenu",
                    "menu",
                    "seatCount",
                    "packingInfo"
                ],
                sourceRows: rows
            ),
            makeInformationSection(
                id: "facility",
                title: "시설·편의 정보",
                rowIDs: [
                    "smokingInfo",
                    "kidsFacilityInfo",
                    "creditCardInfo",
                    "petInfo",
                    "babyCarriageInfo"
                ],
                sourceRows: rows
            ),
            makeInformationSection(
                id: "organizer",
                title: "주최·문의",
                rowIDs: ["sponsor", "sponsorContact"],
                sourceRows: rows
            )
        ]
        .compactMap { $0 }
    }

    private func makeInformationSection(
        id: String,
        title: String,
        rowIDs: [String],
        sourceRows: [TourismDetailInfoRowViewData]
    ) -> TourismDetailInformationSectionViewData? {
        let sectionRows = rowIDs.compactMap { rowID in
            sourceRows.first { $0.id == rowID }
        }

        guard !sectionRows.isEmpty else {
            return nil
        }

        return TourismDetailInformationSectionViewData(
            id: id,
            title: title,
            rows: sectionRows
        )
    }

    private func makeExtraInformationRows(
        from _: TourismDetailIntroduction?
    ) -> [TourismDetailInfoRowViewData] {
        []
    }

    private func makeImageItems(
        from images: [TourismDetailImage]
    ) -> [TourismDetailImageViewData] {
        images.enumerated().compactMap { index, image in
            guard let imageURL = image.originalURL ?? image.smallURL else {
                return nil
            }

            return TourismDetailImageViewData(
                id: nonEmpty(image.serialNumber)
                ?? "image-\(index)-\(imageURL.absoluteString)",
                imageURL: imageURL,
                thumbnailURL: image.smallURL,
                title: nonEmpty(image.name)
            )
        }
    }

    private func isSameContent(_ left: String?, _ right: String?) -> Bool {
        guard let left = nonEmpty(left),
                  let right = nonEmpty(right)
        else {
            return false
        }
        
        let normalizedLeft = left.filter { !$0.isWhitespace }
        let normalizedRight = right.filter { !$0.isWhitespace }
        
        return normalizedLeft == normalizedRight
    }
    
    private func makeRepeatInfoItems(
        from repeatInfo: [TourismDetailRepeatInfo],
        overviewText: String?
    ) -> [TourismDetailRepeatInfoViewData] {
        repeatInfo.enumerated().compactMap { index, item in
            let title = nonEmpty(item.title)
            let originalDescription = nonEmpty(item.description)
            let description = isSameContent(originalDescription, overviewText) ? nil : originalDescription
            let attributeRows: [TourismDetailInfoRowViewData] = []

            guard  description != nil
                    || item.imageURL != nil
                    || !attributeRows.isEmpty
            else {
                return nil
            }

            return TourismDetailRepeatInfoViewData(
                id: nonEmpty(item.serialNumber) ?? "repeat-\(index)",
                title: title ?? "세부 정보",
                description: description,
                imageURL: item.imageURL,
                attributeRows: attributeRows
            )
        }
    }

    private func makePetInformationRows(
        from petTour: TourismPetTour?
    ) -> [TourismDetailInfoRowViewData] {
        guard let petTour else {
            return []
        }

        return [
            makeInfoRow("accidentRisk", title: "사고 위험", value: petTour.accidentRisk),
            makeInfoRow("accompanimentType", title: "동반 유형", value: petTour.accompanimentType),
            makeInfoRow("relatedFacility", title: "관련 시설", value: petTour.relatedFacility),
            makeInfoRow("relatedSupplies", title: "관련 물품", value: petTour.relatedSupplies),
            makeInfoRow("otherInfo", title: "기타 안내", value: petTour.otherInfo),
            makeInfoRow("relatedPurchaseSupplies", title: "구매 가능 물품", value: petTour.relatedPurchaseSupplies),
            makeInfoRow("accompanimentPossibleCapacity", title: "동반 가능 수", value: petTour.accompanimentPossibleCapacity),
            makeInfoRow("relatedRentalSupplies", title: "대여 가능 물품", value: petTour.relatedRentalSupplies),
            makeInfoRow("requiredItems", title: "준비물", value: petTour.requiredItems)
        ]
            .compactMap { $0 }
    }

    private func makeInfoRow(
        _ id: String,
        title: String,
        value: String?
    ) -> TourismDetailInfoRowViewData? {
        guard let value = nonEmpty(value) else {
            return nil
        }

        return TourismDetailInfoRowViewData(
            id: id,
            title: title,
            value: value
        )
    }

    private func nonEmpty(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func makeTelephoneURL(from phoneNumber: String?) -> URL? {
        guard let phoneNumber else {
            return nil
        }

        let digits = phoneNumber.filter(\.isNumber)

        guard !digits.isEmpty else {
            return nil
        }

        return URL(string: "tel:\(digits)")
    }
}
