//
//  TourismDetailView.swift
//  Maplog
//
//  Created by 한채림 on 7/26/26.
//

import SwiftUI

struct TourismDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.maplogLogout) private var performLogout
    @StateObject private var viewModel: TourismDetailViewModel

    init(
        tourismID: Int64,
        tourismRepository: any TourismRepository
    ) {
        _viewModel = StateObject(
            wrappedValue: TourismDetailViewModel(
                tourismID: tourismID,
                tourismRepository: tourismRepository
            )
        )
    }

    var body: some View {
        detailContent
            .toolbar(.hidden, for: .navigationBar)
            .maplogScreenSurface()
            .task {
                await viewModel.load()
            }
            .maplogTabBarHidden()
    }

    @ViewBuilder
    private var detailContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            TourismDetailLoadingView()

        case .content(let detail):
            TourismDetailBasicContent(
                detail: detail,
                onBack: {
                    dismiss()
                }
            )

        case .failed(let presentation):
            TourismDetailFailedView(
                presentation: presentation,
                onRetry: {
                    Task {
                        await viewModel.retry()
                    }
                },
                onSignIn: performLogout,
                onDismiss: {
                    dismiss()
                }
            )
        }
    }
}

private struct TourismDetailLoadingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MaplogSpacing.section) {
                RoundedRectangle(
                    cornerRadius: MaplogRadius.hero,
                    style: .continuous
                )
                .fill(Color.maplogSurfaceRaised)
                .frame(height: 260)

                VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                    RoundedRectangle(cornerRadius: MaplogRadius.small)
                        .fill(Color.maplogSurfaceRaised)
                        .frame(width: 88, height: 24)

                    RoundedRectangle(cornerRadius: MaplogRadius.small)
                        .fill(Color.maplogSurfaceRaised)
                        .frame(width: 220, height: 32)

                    RoundedRectangle(cornerRadius: MaplogRadius.small)
                        .fill(Color.maplogSurfaceRaised)
                        .frame(maxWidth: .infinity)
                        .frame(height: 18)

                    RoundedRectangle(cornerRadius: MaplogRadius.small)
                        .fill(Color.maplogSurfaceRaised)
                        .frame(width: 180, height: 18)
                }

                ProgressView("관광 정보를 불러오는 중이에요")
                    .frame(maxWidth: .infinity)
            }
            .maplogPagePadding()
            .padding(.vertical, MaplogSpacing.pageTop)
        }
        .accessibilityLabel("관광 상세 정보를 불러오는 중")
    }
}

private struct TourismDetailBasicContent: View {
    let detail: TourismDetailViewData
    private let heroPlaceholderHeight: CGFloat = 460
    let onBack: () -> Void

    var body: some View {
        GeometryReader { proxy in
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection(width: proxy.size.width)

                    VStack(alignment: .leading, spacing: MaplogSpacing.section) {
                        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                            
                            if let regionText = detail.regionText {
                                Label(regionText, systemImage: "mappin.and.ellipse")
                                    .font(MaplogFont.callout)
                                    .foregroundStyle(Color.maplogTextSecondary)
                            }
                            
                            if let addressText = detail.addressText {
                                Text(addressText)
                                    .font(MaplogFont.callout)
                                    .foregroundStyle(Color.maplogTextSecondary)
                            }
                            
                            TourismDetailActionSection(
                                title: detail.title,
                                phoneNumber: detail.phoneNumber,
                                phoneURL: detail.phoneURL,
                                homepageURL: detail.homepageURL,
                                coordinate: detail.coordinate
                            )
                        }
                        
                        if let overviewText = detail.overviewText {
                            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                                Text("소개")
                                    .font(MaplogFont.sectionTitle)
                                    .foregroundStyle(Color.maplogTextPrimary)
                                
                                Text(overviewText)
                                    .font(MaplogFont.body)
                                    .foregroundStyle(Color.maplogTextSecondary)
                                    .lineSpacing(5)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        ForEach(detail.informationSections) { section in
                            TourismDetailInformationSection(title: section.title, rows: section.rows)
                        }
                        
                        if !detail.images.isEmpty {
                            TourismDetailImageSection(images: detail.images)
                        }
                        
                        if !detail.repeatInfoItems.isEmpty {
                            TourismDetailRepeatInfoSection(
                                items: detail.repeatInfoItems
                            )
                        }
                        
                        if !detail.petInformationRows.isEmpty {
                            TourismDetailInformationSection(
                                title: "반려동물 동반 안내",
                                rows: detail.petInformationRows
                            )
                        }
                        
                        if !detail.extraInformationRows.isEmpty {
                            TourismDetailInformationSection(
                                title: "추가 정보",
                                rows: detail.extraInformationRows
                            )
                        }
                    }
                    .maplogPagePadding()
                    .padding(.top, MaplogSpacing.section)
                }
                .frame(maxWidth: proxy.size.width,  alignment: .leading)
                .maplogListBottomPadding()
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }
    
    private func heroSection(width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
//            heroImage
//                .frame(maxWidth: .infinity)
            heroImage(width: width)
            
            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.7)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            
            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                HStack(spacing: MaplogSpacing.xSmall) {
                    Text(detail.categoryText)
                        .font(MaplogFont.badge)
                        .foregroundStyle(Color.maplogTextPrimary)
                        .padding(.horizontal, MaplogSpacing.small)
                        .padding(.vertical, MaplogSpacing.xxSmall)
                        .background(Color.maplogPrimary)
                        .clipShape(Capsule())

                    if let statusText = detail.statusText {
                        Text(statusText)
                            .font(MaplogFont.calloutStrong)
                            .foregroundStyle(.white)
                            .shadow(
                                color: .black.opacity(0.35),
                                radius: 2, x: 0, y: 1
                            )
                    }
                }

                Text(detail.title)
                    .font(MaplogFont.screenTitle)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let periodText = detail.periodText {
                    Label(periodText, systemImage: "calendar")
                        .font(MaplogFont.callout)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MaplogSpacing.cardPadding)
        }
        .frame(width: width)
        .overlay(alignment: .topLeading) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(
                        width: MaplogSize.minimumTapTarget,
                        height: MaplogSize.minimumTapTarget
                    )
                    .background(
                        Color.black.opacity(0.18),
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.28), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로가기")
            .padding(.leading, MaplogSpacing.page)
            .padding(
                .top,
                MaplogSpacing.xxxLarge + MaplogSpacing.xSmall
            )
        }
    }
    
    
    @ViewBuilder
    private func heroImage(width: CGFloat) -> some View {
        if let heroImageURL = detail.heroImageURL {
            AsyncImage(url: heroImageURL) { phase in
                switch phase {
                case .empty:
                    heroPlaceholder
                        .overlay {
                            ProgressView()
                        }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: width)

                case .failure:
                    heroPlaceholder

                @unknown default:
                    heroPlaceholder
                }
            }
        } else {
            heroPlaceholder
        }
    }

    private var heroPlaceholder: some View {
        Color.maplogSurfaceRaised
            .frame(height: heroPlaceholderHeight)
            .overlay {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(Color.maplogTextTertiary)
            }

    }
}

private struct TourismDetailInformationSection: View {
    let title: String
    let rows: [TourismDetailInfoRowViewData]

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text(title)
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogTextPrimary)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: MaplogSpacing.small) {
                        Text(row.title)
                            .font(MaplogFont.calloutStrong)
                            .foregroundStyle(Color.maplogTextPrimary)
                            .frame(width: 96, alignment: .leading)

                        Text(row.value)
                            .font(MaplogFont.callout)
                            .foregroundStyle(Color.maplogTextSecondary)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .trailing
                            )
                    }
                    .padding(.vertical, MaplogSpacing.small)

                    if row.id != rows.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, MaplogSpacing.cardPadding)
            .maplogCard()
        }
    }
}

private struct TourismDetailImageSection: View {
    let images: [TourismDetailImageViewData]

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("사진")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogTextPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: MaplogSpacing.small) {
                    ForEach(images) { image in
                        TourismDetailGalleryImage(image: image)
                    }
                }
            }
        }
    }
}

private struct TourismDetailGalleryImage: View {
    let image: TourismDetailImageViewData

    var body: some View {
        AsyncImage(url: image.imageURL) { phase in
            switch phase {
            case .empty:
                Color.maplogSurfaceRaised
                    .overlay {
                        ProgressView()
                    }

            case .success(let loadedImage):
                loadedImage
                    .resizable()
                    .scaledToFill()

            case .failure:
                Color.maplogSurfaceRaised
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(Color.maplogTextTertiary)
                    }

            @unknown default:
                Color.maplogSurfaceRaised
            }
        }
        .frame(width: 260, height: 180)
        .clipped()
        .clipShape(
            RoundedRectangle(
                cornerRadius: MaplogRadius.large,
                style: .continuous
            )
        )
        .accessibilityLabel(image.title ?? "관광지 사진")
    }
}

private struct TourismDetailRepeatInfoSection: View {
    let items: [TourismDetailRepeatInfoViewData]

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("세부 정보")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogTextPrimary)

            VStack(spacing: MaplogSpacing.small) {
                ForEach(items) { item in
                    VStack(
                        alignment: .leading,
                        spacing: MaplogSpacing.small
                    ) {
                        if let imageURL = item.imageURL {
                            AsyncImage(url: imageURL) { phase in
                                switch phase {
                                case .empty:
                                    Color.maplogSurfaceRaised

                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()

                                case .failure:
                                    Color.maplogSurfaceRaised

                                @unknown default:
                                    Color.maplogSurfaceRaised
                                }
                            }
                            .frame(height: 160)
                            .clipped()
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: MaplogRadius.medium,
                                    style: .continuous
                                )
                            )
                        }

                        Text(item.title)
                            .font(MaplogFont.cardTitle)
                            .foregroundStyle(Color.maplogTextPrimary)

                        if let description = item.description {
                            Text(description)
                                .font(MaplogFont.callout)
                                .foregroundStyle(Color.maplogTextSecondary)
                        }

                        if !item.attributeRows.isEmpty {
                            Divider()

                            ForEach(item.attributeRows) { row in
                                HStack(alignment: .top) {
                                    Text(row.title)
                                        .font(MaplogFont.caption)
                                        .foregroundStyle(
                                            Color.maplogTextSecondary
                                        )

                                    Spacer()

                                    Text(row.value)
                                        .font(MaplogFont.caption)
                                        .foregroundStyle(
                                            Color.maplogTextPrimary
                                        )
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                    }
                    .padding(MaplogSpacing.cardPadding)
                    .maplogCard()
                }
            }
        }
    }
}

private struct TourismDetailFailedView: View {
    let presentation: ErrorPresentation
    let onRetry: () -> Void
    let onSignIn: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: MaplogSpacing.medium) {
            ContentUnavailableView(
                "관광 상세 정보를 표시할 수 없어요",
                systemImage: "exclamationmark.triangle",
                description: Text(presentation.message)
            )

            switch presentation.recoveryAction {
            case .retry:
                Button("다시 시도", action: onRetry)
                    .buttonStyle(.borderedProminent)

            case .signIn:
                Button("다시 로그인", action: onSignIn)
                    .buttonStyle(.borderedProminent)

            case .none:
                Button("목록으로 돌아가기", action: onDismiss)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(MaplogSpacing.page)
    }
}

private struct TourismDetailActionSection: View {
    let title: String
    let phoneNumber: String?
    let phoneURL: URL?
    let homepageURL: URL?
    let coordinate: TourismDetailCoordinateViewData?

    var body: some View {
        if phoneURL != nil || homepageURL != nil || coordinate != nil {
            HStack(spacing: MaplogSpacing.small) {
                if let phoneNumber, let phoneURL {
                    Link(destination: phoneURL) {
                        Label("전화", systemImage: "phone.fill")
                    }
                    .buttonStyle(
                        MaplogButtonStyle(
                            variant: .secondary,
                            size: .regular,
                            fullWidth: false
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("\(phoneNumber)로 전화")
                }

                if let homepageURL {
                    Link(destination: homepageURL) {
                        Label("홈페이지", systemImage: "safari")
                    }
                    .buttonStyle(
                        MaplogButtonStyle(
                            variant: .secondary,
                            size: .regular,
                            fullWidth: false
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("홈페이지 열기")
                }

                if let coordinate {
                    NavigationLink { // 지도 화면을 여는 코드
                        TourismLocationMapView(title: title, coordinate: coordinate)
                    } label: {
                        Label("지도 보기", systemImage: "map.fill")
                    }
                    .buttonStyle(
                            MaplogButtonStyle(
                                variant: .secondary,
                                size: .regular,
                                fullWidth: false
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .accessibilityHint("\(title)의 위치 지도 열기")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
