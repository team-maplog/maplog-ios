//
//  FestivalListViewModel.swift
//  Maplog
//
//  Created by 한채림 on 7/22/26.
//

//festivalState       // 첫 화면 상태: loading / content / empty / failed
//items               // 현재 화면에 표시 중인 카드 배열
//isLoadingNextPage   // 기존 카드 아래에서 다음 페이지를 불러오는 중인지
//nextCursor          // 다음 요청 위치
//hasNext             // 더 불러올 축제가 있는지

//첫 페이지, 다음 페이지, 새로고침, 커서 관리

import Foundation

@MainActor
final class FestivalListViewModel: ObservableObject {
    @Published private(set) var festivalState: FestivalListState = .idle // 첫 화면의 loading / content / empty / failed 상태
    @Published private(set) var items: [FestivalListItemViewData] = [] // 현재 그리드에 실제로 표시 중인 축제 카드들
    @Published private(set) var isLoadingNextPage = false // 기존 그리드를 유지한 채 하단에서 다음 페이지를 불러오는 중인지
    
    private let festivalRepository: any FestivalRepository
    private var nextCursor: String? // 다음 API 요청에만 쓰는 서버의 위치표
    private var hasNext = false // 더 불러올 데이터가 있는지
    private let pageSize = 20 // 모든 페이지 요청에서 유지할 개수, 여기서는 20
    
    private let periodDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy. MM. dd."
        return formatter
    }()
    
    init(festivalRepository: any FestivalRepository) {
        self.festivalRepository = festivalRepository
    }
    
//    목록 화면 진입
//    → Repository에 cursor 없이 첫 페이지 요청
//    → Festival을 FestivalListItemViewData로 변환
//    → items에 저장
//    → content / empty / failed 상태 변경
    
    func loadInitialFestivals() async {
        guard festivalState == .idle else{ // 동시에 두 요청 막거나 이미 받은 첫 페이지를 다시 요청하지 않도록 막는 역할
            return
        }
        
        items = []
        nextCursor = nil
        hasNext = false
        festivalState = .initialLoading
        
        do {
            let page = try await festivalRepository.fetchFestivals(cursor: nil, size: pageSize)
            
            guard !Task.isCancelled else {
                festivalState = .idle
                return
            }
            
            let newItems = page.festivals.map { festival in
                makeListItemViewData(from: festival)
            }
            
            items = newItems
            nextCursor = page.nextCursor
            hasNext = page.hasNext
            
            festivalState = newItems.isEmpty ? .empty : .content
        } catch {
            festivalState = .failed(message: festivalErrorMessage(for: error))
        }
    }
    
    private func makeListItemViewData(from festival: Festival) -> FestivalListItemViewData {
        let periodText =
                "\(periodDateFormatter.string(from: festival.startDate)) ~ " +
                "\(periodDateFormatter.string(from: festival.endDate))"

            return FestivalListItemViewData(
                id: festival.id,
                title: festival.name,
                locationText: festival.region ?? "지역 정보 없음",
                periodText: periodText,
                thumbnailURL: festival.thumbnailURL
            )
    }
    
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
    
//    실패
//    → festivalState = .failed
//
//    재시도 버튼 탭
//    → retryInitialFestivals()
//
//    .failed 확인
//    → .idle로 변경
//    → loadInitialFestivals()
//
//    .idle 확인 통과
//    → .initialLoading
//    → 실제 API 재요청
    func retryInitialFestivlas() async {// 실패 상태에서만 동작. 재시도 버튼이 바로 loadInitialFestivals()를 호출하지 않고 이 함수를 부르는 이유는 먼저 .idle로 돌려야 기존의 중복 요청 방지 조건을 통과할 수 있기 때문
        guard case .failed = festivalState else {
            return
        }
        
        festivalState = .idle
        await loadInitialFestivals()

    }
}
