//HomeView
//  → “관광 불러와 줘” 요청
//HomeViewModel
//  → Repository로 API 호출
//  → 관광 데이터를 카드용 데이터와 상태로 변환
//HomeView
//  ← 변경된 상태를 관찰하고 화면을 다시 그림

//HomeTourismCardViewData
//- HomeViewModel이 Tourism을 카드 표시용으로 변환한 결과
//- HomeView가 카드 하나를 그릴 때 사용
//
//HomeTourismSectionState
//- HomeViewModel이 현재 관광 영역의 상태를 표현
//- HomeView가 loading / content / empty / failed 중 무엇을 보여 줄지 결정할 때 사용

//loadInitialTourisms()
//→ Repository에 첫 페이지 요청
//→ 성공이면 카드 데이터 생성
//→ empty / content / failed 상태로 변경

//서버 JSON
//TourismDTO
//↓ Repository
//Tourism
//↓ HomeViewModel의 makeCardViewData
//HomeTourismCardViewData
//↓ HomeView
//화면 카드

//TourismDTO
//- 서버가 보내는 원본 형식
//- 날짜: String
//- 이미지: String
//- 필드명: thumbnailUrl, content
//
//Tourism
//- 앱 내부에서 공통으로 쓰기 좋은 형식
//- 날짜: Date
//- 이미지: URL?
//- region: String?
//
//HomeTourismCardViewData
//- 홈 카드가 바로 그리기 좋은 형식
//- title: String
//- locationText: String
//- periodText: String
//- thumbnailURL: URL?
//View가 “판단·변환”하지 않고, 받은 값을 “표시”만 하게 만들기 위해서

//region: String? → locationText: String, Date → periodText: String이라는 분명한 변환이 있으므로 HomeTourismCardViewData를 두는 게 좋음
//ViewModel은 Repository에게 Tourism을 받아서, 특정 화면이 바로 표시할 수 있는 상태와 문자열


import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var tourismState: HomeTourismSectionState = .idle
    
    private let tourismRepository: any TourismRepository // TourismRepository protocol을 만족하는 어떤 실제 객체 하나(DefaultTourismRepository 객체가 들어감)
    
    init(tourismRepository: any TourismRepository) { // HomeViewModel을 만들 때 Repository를 반드시 전달받게 함
        self.tourismRepository = tourismRepository
    }
    
    func loadInitialTourisms() async {
        guard tourismState != .loading else {
            return
        }
        
        tourismState = .loading
        
        do {
            let page = try await tourismRepository.fetchTourisms(category: .events, cursor: nil, size: 10)
            
            let cards = page.tourisms.map { tourism in
                makeCardViewData(from: tourism) // Tourism들을 카드용 데이터로 변환
            }
            
            tourismState = cards.isEmpty ? .empty : .content(cards)
        } catch is CancellationError { // CancellationError는 탭 이동처럼 화면이 사라져 요청이 취소된 정상 상황이므로 실패 UI로 바꾸지 않음, 실패 화면의 버튼은 retryInitialTourisms()를 호출하는 구조
            return
        } catch {
            tourismState = .failed(TourismErrorPolicy.presentation(for: error))
        }
    }
    
    func retryInitialTourisms() async {
        guard tourismState != .loading else {
            return
        }
        
        tourismState = .idle
        await loadInitialTourisms()
    }
    
    private func makeCardViewData(from tourism: Tourism) -> HomeTourismCardViewData {
        HomeTourismCardViewData(id: tourism.id,
                                title: tourism.name,
                                locationText: tourism.region ?? "지역 정보 없음",
                                periodText: periodText(startDate: tourism.startDate, endDate: tourism.endDate),
                                thumbnailURL: tourism.thumbnailURL)
    }
    
    private let periodDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy. MM. dd."
        return formatter
    }()
    
    private func periodText(startDate: Date?, endDate: Date?) -> String {
        guard let startDate, let endDate else {
                return "기간 정보 없음"
            }

            return "\(periodDateFormatter.string(from: startDate)) ~ \(periodDateFormatter.string(from: endDate))"
    }
    


    
}
