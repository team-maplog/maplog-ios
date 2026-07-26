//
//  TourismListView.swift
//  Maplog
//
//  Created by 한채림 on 7/22/26.
//

// 전체보기 화면 자체
import SwiftUI

struct TourismListView: View {
    @Environment(\.maplogLogout) private var performLogout
    @StateObject private var viewModel: TourismListViewModel // 홈과 달리 TourismListView가 @StateObject를 소유하는 이유는, 목록 ViewModel은 이 목록 화면만을 위해 만들어지고 다른 화면과 공유되지 않기 때문

    private let tourismRepository: any TourismRepository

    private let gridColums: [GridItem] = [
        GridItem(.flexible(minimum: 0), spacing: 32), // 가로: 카드와 카드 사이
        GridItem(.flexible(minimum: 0), spacing: 32)
    ]

    init(tourismRepository: any TourismRepository) {
        self.tourismRepository = tourismRepository // MaplogApp → MainTabView → TourismListView로 이미 주입된 같은 객체
        _viewModel = StateObject(wrappedValue: TourismListViewModel(
            tourismRepository: tourismRepository
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            categoryCarousel
            tourismContent
        }
            .navigationTitle("관광")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: viewModel.selectedCategory) {
                await viewModel.loadInitialTourisms()
            }
    }

    private var categoryCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: MaplogSpacing.xSmall) {
                ForEach(viewModel.categoryTabs) { tab in
                    Button {
                        viewModel.selectCategory(tab.category)
                    } label: {
                        Text(tab.title)
                            .font(MaplogFont.calloutStrong)
                            .foregroundStyle(
                                tab.category == viewModel.selectedCategory
                                ? Color.maplogOnPrimary
                                : Color.maplogTextPrimary
                            )
                            .padding(.horizontal, MaplogSpacing.medium)
                            .frame(minHeight: MaplogSize.minimumTapTarget)
                            .background {
                                Capsule()
                                    .fill(
                                        tab.category == viewModel.selectedCategory
                                        ? Color.maplogPrimary
                                        : Color.maplogSurface
                                    )
                            }
                            .overlay {
                                Capsule()
                                    .stroke(
                                        Color.maplogBorder,
                                        lineWidth: tab.category == viewModel.selectedCategory ? 0 : 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tab.title) 카테고리")
                    .accessibilityValue(
                        tab.category == viewModel.selectedCategory ? "선택됨" : "선택되지 않음"
                    )
                    .accessibilityAddTraits(
                        tab.category == viewModel.selectedCategory ? .isSelected : []
                    )
                }
            }
            .padding(.horizontal, MaplogSpacing.page)
        }
        .padding(.vertical, MaplogSpacing.xxSmall)
        .frame(
                height: MaplogSize.minimumTapTarget
                    + (MaplogSpacing.xxSmall * 2)
            )
        .background(Color.maplogSurface)
    }


    @ViewBuilder
    private var tourismContent: some View {
        switch viewModel.tourismState {
        case .idle, .initialLoading:
            ProgressView("축제 정보를 불러오는 중이에요")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .content:
            tourismGrid
        case .empty:
            ContentUnavailableView("표시할 축제가 없어요",
            systemImage: "calendar.badge.exclamationmark",
                                   description: Text("현재 진행 예정인 축제가 없어요.")
            )
        case .failed(let presentation):
            VStack(spacing: 12) {
                Text(presentation.message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                switch presentation.recoveryAction {
                case .retry:
                    Button("다시 시도") {
                        Task {
                            await viewModel.retryInitialTourisms()
                        }
                    }
                    .buttonStyle(.bordered)

                case .signIn:
                    Button("다시 로그인") {
                        performLogout()
                    }
                    .buttonStyle(.bordered)

                case .none:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    private var tourismGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("현재 \(viewModel.items.count)개 표시 중")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                LazyVGrid(columns: gridColums, spacing: 16) {
                    ForEach(viewModel.items) { item in
                        NavigationLink{
                            TourismDetailView(tourismID: item.id, tourismRepository: tourismRepository)
                        } label: {
                            TourismGridCard(item: item)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("관광 상세 정보 보기")
                        .task {
                            guard item.id == viewModel.items.last?.id else {
                                return
                            }

                            await viewModel.loadNextPage()
                        }
                    }
                }
                if viewModel.isLoadingNextPage {
                    ProgressView("더 불러오는 중이에요")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                if let presentation = viewModel.nextPageError {
                    TourismNextPageErrorFooter(
                        presentation: presentation,
                        onRetry: {
                            Task {
                                await viewModel.retryNextPage()
                            }
                        },
                        onSignIn: performLogout
                    )
                }

            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.vertical, 16)
        }
    }
}

private struct TourismNextPageErrorFooter: View {
    let presentation: ErrorPresentation
    let onRetry: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(presentation.message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            switch presentation.recoveryAction {
            case .retry:
                Button("다시 시도", action: onRetry)
                    .buttonStyle(.bordered)
            case .signIn: // 인증 오류일 때 로그인 화면으로 돌아갈 행동
                Button("다시 로그인", action: onSignIn)
                    .buttonStyle(.bordered)
            case .none:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
