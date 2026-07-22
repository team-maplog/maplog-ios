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
    
    init(apiService: any TourismAPIService) {
        self.apiService = apiService
    }
    
    func fetchTourisms(cursor: String?, size: Int) async throws -> TourismPage {
        let pageDTO = try await apiService.fetchTourisms(cursor: cursor, size: size)
        
        let tourisms = try pageDTO.content.map { tourismDTO in
            try makeTourism(from: tourismDTO)
        }
        
        return TourismPage(tourisms: tourisms, hasNext: pageDTO.hasNext, nextCursor: pageDTO.nextCursor)
    }
    
    private func makeTourism(from dto: TourismDTO) throws -> Tourism {
        let startDate = try date(from: dto.startDate, field: "startDate")
        let endDate = try date(from: dto.endDate, field: "endDate")
        
        return Tourism(
            id: dto.tourismId,
            name: dto.name,
            region: dto.region,
            address: dto.address,
            thumbnailURL: URL(string: dto.thumbnailURL),
            startDate: startDate,
            endDate: endDate,
            category: dto.category
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
