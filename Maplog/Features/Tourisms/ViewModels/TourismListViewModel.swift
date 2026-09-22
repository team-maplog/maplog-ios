//
//  TourismListViewModel.swift
//  Maplog
//
//  Created by 한채림 on 7/22/26.
//

//tourismState        // 첫 화면 상태: loading / content / empty / failed
//items               // 현재 화면에 표시 중인 카드 배열
//isLoadingNextPage   // 기존 카드 아래에서 다음 페이지를 불러오는 중인지
//nextCursor          // 다음 요청 위치
//hasNext             // 더 불러올 축제가 있는지

//첫 페이지, 다음 페이지, 새로고침, 커서 관리

import Foundation

@MainActor
final class TourismListViewModel: ObservableObject {
    @Published private(set) var tourismState: TourismListState = .idle // 첫 화면의 loading / content / empty / failed 상태
    @Published private(set) var items: [TourismListItemViewData] = [] // 현재 그리드에 실제로 표시 중인 관광 카드들
    @Published private(set) var isLoadingNextPage = false // 기존 그리드를 유지한 채 하단에서 다음 페이지를 불러오는 중인지
    @Published private(set) var refreshError: ErrorPresentation?
    @Published private(set) var nextPageError: ErrorPresentation? // 전체보기에서 다음 페이지를 이어 불러올 때 오류, nil: 다음 페이지 관련 오류 없음 | 값 있음: 기존 카드들은 그대로 두고, “더 불러오기 실패” 문구와 재시도 버튼을 보여줄 준비가 됨
    @Published private(set) var selectedCategory: TourismCategory = .events
    
    private let tourismRepository: any TourismRepository
    private var loadRevision = UUID()
    private var isRefreshing = false
    private var nextCursor: String? // 다음 API 요청에만 쓰는 서버의 위치표
    private var hasNext = false // 더 불러올 데이터가 있는지
    private let pageSize = 20 // 모든 페이지 요청에서 유지할 개수, 여기서는 20
    
    let categoryTabs: [TourismCategoryTabViewData] = [
        .init(category: .all, title: "전체 관광"),
        .init(category: .events, title: "행사 전체"),
        .init(category: .festival, title: "축제"),
        .init(category: .performance, title: "공연"),
        .init(category: .event, title: "행사"),
        .init(category: .food, title: "음식점·카페"),
        .init(category: .recommendedCourse, title: "추천 코스"),
        .init(category: .experienceTourism, title: "체험 관광"),
        .init(category: .historyTourism, title: "역사 관광"),
        .init(category: .leisureSports, title: "레저·스포츠"),
        .init(category: .natureTourism, title: "자연 관광"),
        .init(category: .culturalTourism, title: "문화 관광")
    ]

    private let periodDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy. MM. dd."
        return formatter
    }()
    
    init(tourismRepository: any TourismRepository) {
        self.tourismRepository = tourismRepository
    }
    
//    목록 화면 진입
//    → Repository에 cursor 없이 첫 페이지 요청
//    → Tourism을 TourismListItemViewData로 변환
//    → items에 저장
//    → content / empty / failed 상태 변경
    
    func refresh() async {
        guard !isRefreshing, tourismState != .initialLoading, !isLoadingNextPage else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await loadInitialTourisms(policy: .reload)
    }

    func loadInitialTourisms(policy: TourismFetchPolicy = .cached) async {
        let requestedCategory = selectedCategory
        let revision = UUID()
        loadRevision = revision
        
        nextPageError = nil
        refreshError = nil
        let preservesContent = policy == .reload && tourismState == .content
        if !preservesContent {
            items = []
            nextCursor = nil
            hasNext = false
            tourismState = .initialLoading
        }
        isLoadingNextPage = false
        
        do {
            let page = try await tourismRepository.fetchTourisms(
                category: requestedCategory,
                cursor: nil,
                size: pageSize,
                policy: policy
            )
            
            guard !Task.isCancelled, revision == loadRevision, requestedCategory == selectedCategory else {
                return
            }
            
            let newItems = page.tourisms.map { tourism in
                makeListItemViewData(from: tourism)
            }
            
            items = newItems
            nextCursor = page.nextCursor
            hasNext = page.hasNext
            tourismState = newItems.isEmpty ? .empty : .content
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, revision == loadRevision, requestedCategory == selectedCategory else {
                return
            }

            if !preservesContent {
                tourismState = .failed(TourismErrorPolicy.presentation(for: error))
            } else {
                refreshError = TourismErrorPolicy.presentation(for: error)
            }
        }
    }
    
    func loadNextPage() async {
        guard !isRefreshing, tourismState == .content, // 첫 페이지 카드가 이미 성공적으로 있어야 함
              !isLoadingNextPage, // 이미 다음 페이지를 요청 중이면 또 요청하지 않음
              hasNext, // 서버가 “더 있어요”라고 알려줬을 때만 요청
              let nextCursor // 서버가 준 다음 위치표가 실제로 있어야 요청
        else {
            return
        }

        let revision = loadRevision
        let requestedCategory = selectedCategory

        isLoadingNextPage = true
        nextPageError = nil

        defer {
            if revision == loadRevision { isLoadingNextPage = false }
        }

        do {
            let page = try await tourismRepository.fetchTourisms(
                category: requestedCategory,
                cursor: nextCursor,
                size: pageSize
            )

            guard !Task.isCancelled, revision == loadRevision, requestedCategory == selectedCategory else { // 이전 요청의 카드 추가 차단
                return
            }

            let newItems = page.tourisms.map { tourism in
                    makeListItemViewData(from: tourism)
            }

            items.append(contentsOf: newItems)
            self.nextCursor = page.nextCursor
            hasNext = page.hasNext
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, revision == loadRevision, requestedCategory == selectedCategory else { // 이전 요청의 오류 표시 차단
                return
            }

            if TourismErrorPolicy.isCursorInvalid(error) { // 현재 들고 있는 다음 페이지 표지가 더는 유효하지 않을 때 같은 cursor로 재시도하면 또 실패하므로 선택된 카테고리는 유지하고 cursor만 버린 뒤 첫 페이지부터 다시 요청
                await loadInitialTourisms(policy: .reload)
                return
            }

            nextPageError = TourismErrorPolicy.presentation(for: error) // 오류만 따로 저장. 이후 View에서 그리드 하단에만 오류 문구와 재시도 버튼을 보여줌
        }
    }

    func retryNextPage() async {
        guard nextPageError != nil else {
            return
        }

        await loadNextPage()
    }


    private func makeListItemViewData(from tourism: Tourism) -> TourismListItemViewData {
        let formattedPeriodText = periodText(
            startDate: tourism.startDate,
            endDate: tourism.endDate
            )

            return TourismListItemViewData(
                id: tourism.id,
                title: tourism.name,
                locationText: tourism.region ?? "지역 정보 없음",
                periodText: formattedPeriodText,
                thumbnailURL: tourism.thumbnailURL,
                categoryTitle: categoryTabs.first { $0.category == tourism.category }?.title ?? "관광"
            )
    }
    
    private func periodText(startDate: Date?, endDate: Date?) -> String {
        guard let startDate, let endDate else {
            return "기간 정보 없음"
        }

        return "\(periodDateFormatter.string(from: startDate)) ~ \(periodDateFormatter.string(from: endDate))"
    }
    
//    실패
//    → tourismState = .failed
//
//    재시도 버튼 탭
//    → retryInitialTourisms()
//
//    .failed 확인
//    → .idle로 변경
//    → loadInitialTourisms()
//
//    .idle 확인 통과
//    → .initialLoading
//    → 실제 API 재요청
    func retryInitialTourisms() async {// 실패 상태에서만 동작. 재시도 버튼이 바로 loadInitialTourisms()를 호출하지 않고 이 함수를 부르는 이유는 먼저 .idle로 돌려야 기존의 중복 요청 방지 조건을 통과할 수 있기 때문
        guard case .failed = tourismState else {
            return
        }
        
        tourismState = .idle
        await loadInitialTourisms()

    }

    func selectCategory(_ category: TourismCategory) {
        guard selectedCategory != category else {
            return
        }
        // 선택 직후 기존 페이지 요청과 결과를 분리한다. 새 .task 시작 전에도 적용된다.
        loadRevision = UUID()
        items = []
        nextCursor = nil
        hasNext = false
        nextPageError = nil
        refreshError = nil
        isLoadingNextPage = false
        tourismState = .idle
        selectedCategory = category
    }
}
