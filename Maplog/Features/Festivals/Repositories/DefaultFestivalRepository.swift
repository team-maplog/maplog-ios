//
//  DefaultFestivalRepository.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

//- FestivalAPIService로 FestivalPageDTO 받기
//- FestivalDTO의 String 날짜를 Date로 파싱
//- 이미지 문자열을 URL?로 변환
//- DTO의 content를 Domain Model의 festivals로 변환
//- FestivalPage 반환

//서버 언어를 앱 언어로 번역

//FestivalPageDTO
//- content
//- String 날짜
//- String 이미지 주소
//
//↓ Repository가 변환
//
//FestivalPage
//- festivals
//- Date 날짜
//- URL? 이미지 주소

//Repository는 구체 클래스가 아니라 FestivalAPIService protocol에 의존
//A가 자기 일을 하려면 B가 필요하다면, A는 B에 의존한다.
//DefaultFestivalRepository는 서버에서 받은 FestivalPageDTO가 있어야 자기 일을 할 수 있음. 그런데 DTO를 가져오는 담당은 API Service
//그래서 Repository는 API Service가 필요

import Foundation

final class DefaultFestivalRepository: FestivalRepository {
    private let apiService: any FestivalAPIService
    
    init(apiService: any FestivalAPIService) {
        self.apiService = apiService
    }
    
    func fetchFestivals(cursor: String?, size: Int) async throws -> FestivalPage {
        let pageDTO = try await apiService.fetchFestivals(cursor: cursor, size: size)
        
        let festivals = try pageDTO.content.map { festivalDTO in
            try makeFestival(from: festivalDTO)
        }
        
        return FestivalPage(festivals: festivals, hasNext: pageDTO.hasNext, nextCursor: pageDTO.nextCursor)
    }
    
    private func makeFestival(from dto: FestivalDTO) throws -> Festival {
        guard let startDate = parseDate(dto.startDate) else {
            throw FestivalRepositoryError.invalidDate(field: "startDate", value: dto.startDate)
        }
        
        guard let endDate = parseDate(dto.endDate) else {
            throw FestivalRepositoryError.invalidDate(field: "endDate", value: dto.endDate)
        }
        
        return Festival(
            id: dto.festivalId,
            name: dto.name,
            region: dto.region,
            thumbnailURL: URL(string: dto.thumbnailURL),
            startDate: startDate, endDate: endDate)
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
//2. DTO의 content 각각을 Festival로 변환
//3. FestivalPage로 묶어서 ViewModel에 반환
