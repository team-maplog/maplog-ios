//HomeView
//  → “축제 불러와 줘” 요청
//HomeViewModel
//  → Repository로 API 호출
//  → 축제 데이터를 카드용 데이터와 상태로 변환
//HomeView
//  ← 변경된 상태를 관찰하고 화면을 다시 그림

//HomeFestivalCardViewData
//- HomeViewModel이 Festival을 카드 표시용으로 변환한 결과
//- HomeView가 카드 하나를 그릴 때 사용
//
//HomeFestivalSectionState
//- HomeViewModel이 현재 축제 영역의 상태를 표현
//- HomeView가 loading / content / empty / failed 중 무엇을 보여 줄지 결정할 때 사용

//loadInitialFestivals()
//→ Repository에 첫 페이지 요청
//→ 성공이면 카드 데이터 생성
//→ empty / content / failed 상태로 변경

//서버 JSON
//FestivalDTO
//↓ Repository
//Festival
//↓ HomeViewModel의 makeCardViewData
//HomeFestivalCardViewData
//↓ HomeView
//화면 카드

//FestivalDTO
//- 서버가 보내는 원본 형식
//- 날짜: String
//- 이미지: String
//- 필드명: thumbnailUrl, content
//
//Festival
//- 앱 내부에서 공통으로 쓰기 좋은 형식
//- 날짜: Date
//- 이미지: URL?
//- region: String?
//
//HomeFestivalCardViewData
//- 홈 카드가 바로 그리기 좋은 형식
//- title: String
//- locationText: String
//- periodText: String
//- thumbnailURL: URL?
//View가 “판단·변환”하지 않고, 받은 값을 “표시”만 하게 만들기 위해서

//region: String? → locationText: String, Date → periodText: String이라는 분명한 변환이 있으므로 HomeFestivalCardViewData를 두는 게 좋음

import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var festivalState: HomeFestivalSectionState = .idle
    
    private let festivalRepository: any FestivalRepository // FestivalRepository protocol을 만족하는 어떤 실제 객체 하나(DefaultFestivalRepository 객체가 들어감)
    
    init(festivalRepository: any FestivalRepository) { // HomeViewModel을 만들 때 Repository를 반드시 전달받게 함
        self.festivalRepository = festivalRepository
    }
    
    func loadInitialFestivals() async {
        guard festivalState != .loading else {
            return
        }
        
        festivalState = .loading
        
        do {
            let page = try await festivalRepository.fetchFestivals(cursor: nil, size: 10)
            
            let cards = page.festivals.map { festival in
                makeCardViewData(from: festival) // Festival들을 카드용 데이터로 변환
            }
            
            festivalState = cards.isEmpty ? .empty : .content(cards)
        } catch is CancellationError { // CancellationError는 탭 이동처럼 화면이 사라져 요청이 취소된 정상 상황이므로 실패 UI로 바꾸지 않음, 실패 화면의 버튼은 retryInitialFestivals()를 호출하는 구조
            return
        } catch {
            festivalState = .failed(message: festivalErrorMessage(for: error))
        }
    }
    
    func retryInitialFestivals() async {
        guard festivalState != .loading else {
            return
        }
        
        festivalState = .idle
        await loadInitialFestivals()
    }
    
    private func makeCardViewData(from festival: Festival) -> HomeFestivalCardViewData {
        HomeFestivalCardViewData(id: festival.id,
                                 title: festival.name,
                                 locationText: festival.region ?? "지역 정보 없음",
                                 periodText: periodText(startDate: festival.startDate, endDate: festival.endDate),
                                 thumbnailURL: festival.thumbnailURL)
    }
    
    private func periodText(startDate: Date, endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy. MM. dd."

        return "\(formatter.string(from: startDate)) ~ \(formatter.string(from: endDate))"
    }
    // API 오류를 사용자용 문구로 바꾸는 함수
    private func festivalErrorMessage(for error: Error) -> String {
        guard let apiError = error as? APIError else {
            return "축제 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
        }
        
        switch apiError {
        case .server(_, let response) where response.code == "TOUR-001":
            return "현재 축제 정보를 이용할 수 없어요."
            
        case .server(_, let response) where response.code == "TOUR-002":
            return "축제 정보를 불러오는 중 문제가 생겼어요. 잠시 후 다시 시도해 주세요."
            
        case .network:
            return "인터넷 연결을 확인한 뒤 다시 시도해 주세요."
            
        default:
                return "축제 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }
    
}

