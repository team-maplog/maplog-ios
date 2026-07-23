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
    @Published private(set) var nextPageError: ErrorPresentation? // 전체보기에서 다음 페이지를 이어 불러올 때 오류, nil: 다음 페이지 관련 오류 없음 | 값 있음: 기존 카드들은 그대로 두고, “더 불러오기 실패” 문구와 재시도 버튼을 보여줄 준비가 됨
    
    private let tourismRepository: any TourismRepository
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
    
    init(tourismRepository: any TourismRepository) {
        self.tourismRepository = tourismRepository
    }
    
//    목록 화면 진입
//    → Repository에 cursor 없이 첫 페이지 요청
//    → Tourism을 TourismListItemViewData로 변환
//    → items에 저장
//    → content / empty / failed 상태 변경
    
    func loadInitialTourisms() async {
        guard tourismState == .idle else{ // 동시에 두 요청 막거나 이미 받은 첫 페이지를 다시 요청하지 않도록 막는 역할
            return
        }
        
        nextPageError = nil
        items = []
        nextCursor = nil
        hasNext = false
        tourismState = .initialLoading
        
        do {
            let page = try await tourismRepository.fetchTourisms(
                category: .all,
                cursor: nil,
                size: pageSize)
            
            guard !Task.isCancelled else {
                tourismState = .idle
                return
            }
            
            let newItems = page.tourisms.map { tourism in
                makeListItemViewData(from: tourism)
            }
            
            items = newItems
            nextCursor = page.nextCursor
            hasNext = page.hasNext
            
            tourismState = newItems.isEmpty ? .empty : .content
        } catch {
            tourismState = .failed(TourismErrorPolicy.presentation(for: error))
        }
    }
    
    func loadNextPage() async {
        guard tourismState == .content, // 첫 페이지 카드가 이미 성공적으로 있어야 함
              !isLoadingNextPage, // 이미 다음 페이지를 요청 중이면 또 요청하지 않음
              hasNext, // 서버가 “더 있어요”라고 알려줬을 때만 요청
              let nextCursor // 서버가 준 다음 위치표가 실제로 있어야 요청
        else {
            return
        }

        isLoadingNextPage = true
        nextPageError = nil

        defer {
            isLoadingNextPage = false
        }

        do {
            let page = try await tourismRepository.fetchTourisms(
                category: .all,
                cursor: nextCursor,
                size: pageSize
            )

            guard !Task.isCancelled else {
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
        } catch { // 오류만 따로 저장. 이후 View에서 그리드 하단에만 오류 문구와 재시도 버튼을 보여줌
            nextPageError = TourismErrorPolicy.presentation(for: error)
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
                thumbnailURL: tourism.thumbnailURL
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
}
