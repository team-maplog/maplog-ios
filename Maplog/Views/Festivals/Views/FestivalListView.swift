//
//  FestivalListView.swift
//  Maplog
//
//  Created by 한채림 on 7/22/26.
//

// 전체보기 화면 자체
import SwiftUI

struct FestivalListView: View {
    @StateObject private var viewModel: FestivalListViewModel // 홈과 달리 FestivalListView가 @StateObject를 소유하는 이유는, 목록 ViewModel은 이 목록 화면만을 위해 만들어지고 다른 화면과 공유되지 않기 때문
    
    private let gridColums: [GridItem] = [
        GridItem(.flexible(minimum: 0), spacing: 32), // 가로: 카드와 카드 사이
        GridItem(.flexible(minimum: 0), spacing: 32)
    ]
    
    init(festivalRepository: any FestivalRepository) {
        _viewModel = StateObject(wrappedValue: FestivalListViewModel(
            festivalRepository: festivalRepository
        ))
    }
    
    var body: some View {
        festivalContent
            .navigationTitle("축제")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadInitialFestivals()
            }
    }
    
    @ViewBuilder
    private var festivalContent: some View {
        switch viewModel.festivalState {
        case .idle, .initialLoading:
            ProgressView("축제 정보를 불러오는 중이에요")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .content:
            festivalGrid
        case .empty:
            ContentUnavailableView("표시할 축제가 없어요",
            systemImage: "calendar.badge.exclamationmark",
                                   description: Text("현재 진행 예정인 축제가 없어요.")
            )
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                
                Button("다시 시도") {
                    Task {
                        await viewModel.retryInitialFestivlas() // 화면 진입 시 비동기 API 요청
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
    
    private var festivalGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("현재 \(viewModel.items.count)개 표시 중")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                
                LazyVGrid(columns: gridColums, spacing: 16) {
                    ForEach(viewModel.items) { item in
                            FestivalGridCard(item: item)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.vertical, 16)
        }
    }
}
