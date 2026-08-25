//
//  TourismListView.swift
//  Maplog
//
//  Created by 한채림 on 7/22/26.
//

// 전체보기 화면 자체
import SwiftUI

struct TourismListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.maplogLogout) private var performLogout
    @StateObject private var viewModel: TourismListViewModel // 홈과 달리 TourismListView가 @StateObject를 소유하는 이유는, 목록 ViewModel은 이 목록 화면만을 위해 만들어지고 다른 화면과 공유되지 않기 때문

    private let tourismRepository: any TourismRepository

    private var gridCategoryTitle: String {
        switch viewModel.selectedCategory {
        case .all:
            return "관광"
        case .events:
            return "행사"
        default:
            return viewModel.categoryTabs.first {
                $0.category == viewModel.selectedCategory
            }?.title ?? "관광"
        }
    }

    init(tourismRepository: any TourismRepository) {
        self.tourismRepository = tourismRepository // MaplogApp → MainTabView → TourismListView로 이미 주입된 같은 객체
        _viewModel = StateObject(wrappedValue: TourismListViewModel(
            tourismRepository: tourismRepository
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            categoryCarousel
            Divider()
            tourismContent
        }
        // iOS의 기본 뒤로가기 버튼은 OS 버전에 따라 원형 유리 버튼이 된다.
        // 시안처럼 얇은 chevron을 고정하기 위해 이 화면만 자체 헤더를 사용한다.
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            TourismListNavigationBar(onBack: dismiss.callAsFunction)
        }
        .background(Color.white.ignoresSafeArea())
        .maplogTabBarHidden()
        .task(id: viewModel.selectedCategory) {
            await viewModel.loadInitialTourisms()
        }
    }

    private var categoryCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: MaplogSpacing.xSmall) {
                ForEach(viewModel.categoryTabs) { tab in
                    Button(action: { selectCategory(tab.category) }) {
                        Text(tab.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                tab.category == viewModel.selectedCategory
                                ? Color.maplogOnPrimary
                                : Color.maplogTextPrimary
                            )
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background {
                                Capsule()
                                    .fill(
                                        tab.category == viewModel.selectedCategory
                                ? Color.maplogPrimary
                                : Color.white
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
                    .frame(minHeight: MaplogSize.minimumTapTarget)
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
        .frame(height: 52)
        .background(Color.white)
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
        GeometryReader { proxy in
            // 카드가 사용할 수 있는 실제 가로 폭을 먼저 계산한다.
            // 그 값을 GridItem과 카드에 동시에 전달해야 텍스트가 길어도
            // 두 번째 열이 화면 밖으로 밀려나지 않는다.
            let horizontalPadding = MaplogSpacing.xLarge
            let columnSpacing = MaplogSpacing.small
            let cardWidth = max(
                0,
                (proxy.size.width - (horizontalPadding * 2) - columnSpacing) / 2
            )
            let columns = [
                GridItem(.fixed(cardWidth), spacing: columnSpacing),
                GridItem(.fixed(cardWidth), spacing: columnSpacing)
            ]

            ScrollView {
                VStack(alignment: .leading, spacing: MaplogSpacing.large) {
                    HStack {
                        Text("\(viewModel.items.count)개")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.maplogTextSecondary)

                        Spacer()

                        Label("추천순", systemImage: "arrow.up.arrow.down")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.maplogTextSecondary)
                    }

                    LazyVGrid(
                        columns: columns,
                        alignment: .leading,
                        spacing: MaplogSpacing.xLarge
                    ) {
                        ForEach(viewModel.items) { item in
                            NavigationLink {
                                TourismDetailView(tourismID: item.id, tourismRepository: tourismRepository)
                            } label: {
                                TourismGridCard(
                                    item: item,
                                    categoryTitle: gridCategoryTitle,
                                    cardWidth: cardWidth
                                )
                            }
                            .buttonStyle(.plain)
                            .frame(width: cardWidth, alignment: .topLeading)
                            .accessibilityHint("관광 상세 정보 보기")
                            .task {
                                await loadNextPageIfNeeded(for: item)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, MaplogSpacing.large)
                .padding(.bottom, MaplogSpacing.xxLarge)
            }
            .background(Color.white)
        }
    }

    private func selectCategory(_ category: TourismCategory) {
        viewModel.selectCategory(category)
    }

    private func loadNextPageIfNeeded(
        for item: TourismListItemViewData
    ) async {
        guard item.id == viewModel.items.last?.id else {
            return
        }

        await viewModel.loadNextPage()
    }
}

private struct TourismListNavigationBar: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(Color.maplogTextPrimary)
                    .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로가기")

            Spacer()

            Text("관광")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.maplogTextPrimary)

            Spacer()

            Color.clear
                .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
        }
        .padding(.horizontal, MaplogSpacing.xLarge)
        .frame(height: 52)
        .background(Color.white)
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
