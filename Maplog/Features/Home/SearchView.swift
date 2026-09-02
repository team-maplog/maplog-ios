import SwiftUI
import UIKit

/// 홈의 검색 버튼에서 열리는 실제 통합 검색 화면입니다.
/// 화면은 입력·탭·카드만 그리고, 검색 상태와 네트워크 작업은 HomeSearchViewModel에 맡깁니다.
struct HomeSearchFeatureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.maplogLogout) private var performLogout
    @FocusState private var isSearchFieldFocused: Bool
    @StateObject private var viewModel: HomeSearchViewModel

    private let onShowLogDetail: (Int64) -> Void
    private let onShowTourismDetail: (Int64) -> Void

    init(
        searchRepository: any HomeSearchRepository,
        logMediaRepository: any LogMediaRepository,
        logReelRepository: any LogReelRepository,
        onShowLogDetail: @escaping (Int64) -> Void,
        onShowTourismDetail: @escaping (Int64) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: HomeSearchViewModel(
                searchRepository: searchRepository,
                logMediaRepository: logMediaRepository,
                logReelRepository: logReelRepository
            )
        )
        self.onShowLogDetail = onShowLogDetail
        self.onShowTourismDetail = onShowTourismDetail
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { viewModel.query },
            set: viewModel.updateQuery
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                searchHeader
                    .padding(.top, 12)

                if !viewModel.trimmedQuery.isEmpty || viewModel.state != .idle {
                    scopeChips
                        .padding(.top, 22)
                }

                if let validationMessage = viewModel.inputValidationMessage {
                    Text(validationMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                }

                searchContent
                    .padding(.top, 26)
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.bottom, 112)
        }
        .background(Color.maplogCanvas.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .simultaneousGesture(
            TapGesture().onEnded {
                isSearchFieldFocused = false
            }
        )
        .task {
            await viewModel.loadRecentLogsIfNeeded()
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(
                        width: MaplogSize.minimumTapTarget,
                        height: MaplogSize.minimumTapTarget
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로 가기")

            HStack(spacing: 10) {
                TextField("장소나 맵로그를 검색하세요", text: queryBinding)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.maplogInk)
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        Task {
                            await viewModel.submitSearch()
                        }
                    }

                Button {
                    Task {
                        await viewModel.submitSearch()
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            viewModel.canSubmit
                                ? Color.maplogInk
                                : Color.maplogMuted
                        )
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSubmit)
                .accessibilityLabel("검색")

                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.updateQuery("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.maplogMuted.opacity(0.72))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("검색어 지우기")
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(height: 52)
            .background(Color.white, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.maplogBorder, lineWidth: 1)
            }
        }
    }

    private var scopeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(HomeSearchScope.allCases) { scope in
                    Button {
                        Task {
                            await viewModel.selectScope(scope)
                        }
                    } label: {
                        Text(scopeTitle(scope))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                viewModel.selectedScope == scope
                                    ? Color.maplogOnPrimary
                                    : Color.maplogInk
                            )
                            .padding(.horizontal, 17)
                            .frame(height: 42)
                            .background(
                                viewModel.selectedScope == scope
                                    ? Color.maplogPrimary
                                    : Color.white,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(
                                        viewModel.selectedScope == scope
                                            ? .clear
                                            : Color.maplogBorder,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        viewModel.selectedScope == scope
                            ? .isSelected
                            : []
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        switch viewModel.state {
        case .idle:
            exploreContent

        case .initialLoading:
            ProgressView("검색 결과를 불러오는 중이에요")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 96)

        case .empty:
            HomeSearchEmptyState(query: viewModel.trimmedQuery)

        case .failed(let presentation):
            HomeSearchFailedState(
                presentation: presentation,
                onRetry: {
                    Task {
                        await viewModel.retryInitialSearch()
                    }
                },
                onSignIn: performLogout
            )

        case .content:
            VStack(alignment: .leading, spacing: 16) {
                Text("\(viewModel.trimmedQuery) 검색 결과")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)

                resultGrid

                if viewModel.visibleItems.isEmpty {
                    if viewModel.isPrefetchingSearchThumbnails {
                        HomeSearchImageLoadingState()
                    } else {
                        HomeSearchNoImageState()
                    }
                }

                if viewModel.isLoadingNextPage {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                if let presentation = viewModel.nextPageError {
                    HomeSearchNextPageError(
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
        }
    }

    private var resultGrid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 4),
                count: 3
            ),
            spacing: 4
        ) {
            ForEach(viewModel.visibleItems) { item in
                Button {
                    open(item)
                } label: {
                    HomeSearchThumbnailCard(
                        item: item,
                        thumbnailData: viewModel.thumbnailData(for: item)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: item))
                .accessibilityHint("상세 화면으로 이동")
                .task {
                    await viewModel.loadNextPageIfNeeded(for: item)
                }
            }
        }
        .task(id: viewModel.items.map(\.id)) {
            await viewModel.loadThumbnails(for: viewModel.items)
        }
        .animation(
            .easeOut(duration: 0.18),
            value: viewModel.visibleItems.map(\.id)
        )
    }

    @ViewBuilder
    private var exploreContent: some View {
        switch viewModel.exploreState {
        case .idle, .loading:
            ProgressView("최근 맵로그를 불러오는 중이에요")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 96)

        case .empty:
            ContentUnavailableView(
                "아직 공개된 맵로그가 없어요",
                systemImage: "play.rectangle"
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 96)

        case .failed(let presentation):
            HomeSearchFailedState(
                presentation: presentation,
                onRetry: {
                    Task {
                        await viewModel.retryRecentLogs()
                    }
                },
                onSignIn: performLogout
            )

        case .content:
            VStack(alignment: .leading, spacing: 16) {
                Text("최근 올라온 맵로그")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.maplogInk)

                recentLogGrid

                if viewModel.visibleRecentLogs.isEmpty {
                    if viewModel.isPrefetchingRecentThumbnails {
                        HomeSearchImageLoadingState()
                    } else {
                        HomeSearchNoImageState()
                    }
                }
            }
        }
    }

    private var recentLogGrid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 4),
                count: 3
            ),
            spacing: 4
        ) {
            ForEach(viewModel.visibleRecentLogs) { log in
                Button {
                    isSearchFieldFocused = false
                    onShowLogDetail(log.id)
                } label: {
                    HomeSearchThumbnailCard(
                        itemKind: .log,
                        thumbnailData: viewModel.recentThumbnailData(for: log)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("최근 맵로그 \(log.caption)")
                .accessibilityHint("로그 상세 화면으로 이동")
            }
        }
        .task(id: viewModel.recentLogs.map(\.id)) {
            await viewModel.loadRecentThumbnails()
        }
        .animation(
            .easeOut(duration: 0.18),
            value: viewModel.visibleRecentLogs.map(\.id)
        )
    }

    private func scopeTitle(_ scope: HomeSearchScope) -> String {
        guard let count = viewModel.scopeCounts[scope] else {
            return scope.title
        }

        return "\(scope.title) \(count)"
    }

    private func open(_ item: HomeSearchItem) {
        isSearchFieldFocused = false

        switch item.kind {
        case .log:
            onShowLogDetail(item.serverID)
        case .tourism:
            onShowTourismDetail(item.serverID)
        }
    }

    private func accessibilityLabel(for item: HomeSearchItem) -> String {
        switch item.kind {
        case .log:
            return "맵로그 \(item.title)"
        case .tourism:
            return "관광 \(item.title)"
        }
    }
}

private struct HomeSearchThumbnailCard: View {
    let itemKind: HomeSearchItem.Kind
    let thumbnailData: Data?

    init(
        item: HomeSearchItem,
        thumbnailData: Data?
    ) {
        self.itemKind = item.kind
        self.thumbnailData = thumbnailData
    }

    init(
        itemKind: HomeSearchItem.Kind,
        thumbnailData: Data?
    ) {
        self.itemKind = itemKind
        self.thumbnailData = thumbnailData
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                if let thumbnailData,
                   let image = UIImage(data: thumbnailData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.height
                        )
                        .clipped()
                }

                marker
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
            .background(Color.clear)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: MaplogRadius.medium,
                    style: .continuous
                )
            )
        }
        // 카드 폭을 기준으로 세로 길이를 고정해 어떤 원본 이미지도 같은 그리드 칸을 사용합니다.
        .aspectRatio(0.72, contentMode: .fit)
        .contentShape(RoundedRectangle(cornerRadius: MaplogRadius.medium))
    }

    @ViewBuilder
    private var marker: some View {
        switch itemKind {
        case .log:
            Image(systemName: "play.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.black.opacity(0.58), in: Circle())
                .padding(7)

        case .tourism:
            MaplogPinGlyphIcon(size: 17)
                .foregroundStyle(Color.maplogPrimary)
                .background(Circle().fill(.white.opacity(0.94)).padding(1.5))
                .padding(7)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
        }
    }
}

private struct HomeSearchImageLoadingState: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .accessibilityLabel("이미지를 불러오는 중")
    }
}

private struct HomeSearchNoImageState: View {
    var body: some View {
        Text("표시할 사진이 있는 결과가 없어요")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.maplogMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
    }
}

private struct HomeSearchEmptyState: View {
    let query: String

    var body: some View {
        ContentUnavailableView(
            "검색 결과가 없어요",
            systemImage: "magnifyingglass",
            description: Text("‘\(query)’와(과) 맞는 맵로그나 관광 정보를 찾지 못했어요.")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 96)
    }
}

private struct HomeSearchFailedState: View {
    let presentation: ErrorPresentation
    let onRetry: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.maplogMuted)

            Text(presentation.message)
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)

            switch presentation.recoveryAction {
            case .retry:
                Button("다시 시도", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.maplogPrimary)
            case .signIn:
                Button("다시 로그인", action: onSignIn)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.maplogPrimary)
            case .none:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 96)
    }
}

private struct HomeSearchNextPageError: View {
    let presentation: ErrorPresentation
    let onRetry: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(presentation.message)
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)

            switch presentation.recoveryAction {
            case .retry:
                Button("더 불러오기", action: onRetry)
                    .font(MaplogFont.calloutStrong)
                    .foregroundStyle(Color.maplogInk)
            case .signIn:
                Button("다시 로그인", action: onSignIn)
                    .font(MaplogFont.calloutStrong)
                    .foregroundStyle(Color.maplogInk)
            case .none:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// 기존 촬영 화면의 태그 선택에도 쓰이는 공용 Chip 그리드입니다.
// 홈 검색 결과 전용 UI와 분리해 두면, 검색 화면을 바꿔도 촬영 화면이 영향을 받지 않습니다.
struct FlowChips: View {
    let items: [String]
    var selectedItem: String?
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: 82),
                    spacing: MaplogSpacing.xSmall
                )
            ],
            alignment: .leading,
            spacing: MaplogSpacing.xSmall
        ) {
            ForEach(items, id: \.self) { item in
                Button {
                    onSelect(item)
                } label: {
                    ChipView(
                        title: item,
                        isSelected: selectedItem == item
                    )
                }
                .buttonStyle(MaplogPressFeedbackStyle())
            }
        }
    }
}
