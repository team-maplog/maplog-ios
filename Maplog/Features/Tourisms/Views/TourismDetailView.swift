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

    private var quickInformationSection: TourismDetailInformationSectionViewData? {
        detail.informationSections.first { $0.id == "quick" }
    }

    private var organizerInformationSection: TourismDetailInformationSectionViewData? {
        detail.informationSections.first { $0.id == "organizer" }
    }

    private var detailedInformationSections: [TourismDetailInformationSectionViewData] {
        detail.informationSections.filter { $0.id != "quick" && $0.id != "organizer" }
    }





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
                                phoneNumber: detail.phoneNumber,
                                phoneURL: detail.phoneURL,
                                homepageURL: detail.homepageURL,
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

                        if let quickInformationSection {
                            TourismDetailQuickInfoSection(rows: quickInformationSection.rows)
                        }

                        if let coordinate = detail.coordinate {
                            TourismDetailLocationPreviewSection(title: detail.title, addressText: detail.addressText, coordinate: coordinate)
                        }

                        if !detail.programLines.isEmpty {
                            TourismDetailProgramSection(lines: detail.programLines)
                        }

                        ForEach(detailedInformationSections) { section in
                            TourismDetailInformationSection(title: section.title, rows: section.rows, layout: .detail)
                        }

                        if let organizerInformationSection {
                            TourismDetailOrganizerSection(rows: organizerInformationSection.rows)
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
                                rows: detail.petInformationRows,
                                layout: .detail
                            )
                        }

                        if !detail.extraInformationRows.isEmpty {
                            TourismDetailInformationSection(
                                title: "추가 정보",
                                rows: detail.extraInformationRows,
                                layout: .detail
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

private struct TourismDetailQuickInfoSection: View {
    let rows: [TourismDetailInfoRowViewData]

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: MaplogSpacing.small) {
                    Image(systemName: iconName(for: row.id))
                        .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                        .foregroundStyle(Color.maplogOlive)
                        .frame(width: MaplogSize.iconMedium)

                    VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                        Text(row.title)
                            .font(MaplogFont.caption)
                                                        .foregroundStyle(Color.maplogTextSecondary)

                                                    Text(row.value)
                                                        .font(MaplogFont.calloutStrong)
                                                        .foregroundStyle(Color.maplogTextPrimary)
                                                        .fixedSize(
                                                            horizontal: false,
                                                            vertical: true
                                                        )
                    }
                }
            }
        }
        .padding(.vertical, MaplogSpacing.xSmall)
    }
    private func iconName(for rowID: String) -> String {
            switch rowID {
            case "openingHours":
                return "clock"

            case "place":
                return "mappin.and.ellipse"

            case "usageFee":
                return "ticket"

            default:
                return "info.circle"
            }
        }
}

private struct TourismDetailInformationSection: View {
    enum Layout {
        case summary
        case detail
    }
    let title: String
    let rows: [TourismDetailInfoRowViewData]
    let layout: Layout

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text(title)
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogTextPrimary)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    informationRow(row)

                    if row.id != rows.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, MaplogSpacing.cardPadding)
            .maplogCard()
        }
    }

    @ViewBuilder
    private func informationRow(_ row: TourismDetailInfoRowViewData) -> some View {
        switch layout {
        case .summary:
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

        case .detail:
            VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                if row.title != title {
                    Text(row.title)
                        .font(MaplogFont.calloutStrong)
                        .foregroundStyle(Color.maplogTextPrimary)
                }

                Text(row.value)
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(MaplogSpacing.xxSmall)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .textSelection(.enabled)
            }
            .padding(.vertical, MaplogSpacing.medium)
        }
    }
}

private struct TourismDetailProgramSection: View {
    let lines: [TourismDetailContentLineViewData]

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("프로그램")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogTextPrimary)

            VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
                ForEach(lines) { line in
                    programLine(line)
                }
            }
            .padding(MaplogSpacing.cardPadding)
            .maplogCard()
        }
    }

    @ViewBuilder
    private func programLine(_ line: TourismDetailContentLineViewData) -> some View {
        switch line.style {
        case .heading:
            Text(line.text)
                .font(MaplogFont.calloutStrong)
                .foregroundStyle(Color.maplogTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, MaplogSpacing.xSmall)

        case .bullet:
            HStack(alignment: .top, spacing: MaplogSpacing.xSmall) {
                Text("•")
                        .font(MaplogFont.calloutStrong)
                        .foregroundStyle(Color.maplogPrimary)

                Text(line.text)
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogTextSecondary)
                        .lineSpacing(MaplogSpacing.xxSmall)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .body:
                    Text(line.text)
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogTextSecondary)
                        .lineSpacing(MaplogSpacing.xxSmall)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TourismDetailOrganizerSection: View {
    let rows: [TourismDetailInfoRowViewData]

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("주최·문의")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogTextPrimary)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    organizerRow(row)

                    if row.id != rows.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, MaplogSpacing.cardPadding)
            .maplogCard()
        }
    }

    private func organizerRow(
        _ row: TourismDetailInfoRowViewData
    ) -> some View {
        HStack(alignment: .top, spacing: MaplogSpacing.small) {
            Image(systemName: iconName(for: row.id))
                .font(MaplogFont.calloutStrong)
                .foregroundStyle(Color.maplogOlive)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                Text(row.title)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogTextSecondary)

                Text(row.value)
                    .font(MaplogFont.calloutStrong)
                    .foregroundStyle(Color.maplogTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, MaplogSpacing.medium)
    }

    private func iconName(for rowID: String) -> String {
        switch rowID {
        case "sponsor":
            return "building.2"

        case "sponsorContact":
            return "phone"

        default:
            return "info.circle"
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
                    TourismDetailRepeatInfoCard(item: item)
                }
            }
        }
    }
}

private struct TourismDetailRepeatInfoCard: View {
    let item: TourismDetailRepeatInfoViewData

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
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
                .frame(height: 180)
                .clipped()
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MaplogRadius.medium,
                        style: .continuous
                    )
                )
            }

            Label(item.title, systemImage: "text.alignleft")
                .font(MaplogFont.cardTitle)
                .foregroundStyle(Color.maplogTextPrimary)

            if !item.contentLines.isEmpty {
                VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
                    ForEach(item.contentLines) { line in
                        contentLine(line)
                    }
                }
            }

            if !item.attributeRows.isEmpty {
                Divider()

                ForEach(item.attributeRows) { row in
                    VStack(
                        alignment: .leading,
                        spacing: MaplogSpacing.xxxSmall
                    ) {
                        Text(row.title)
                            .font(MaplogFont.caption)
                            .foregroundStyle(Color.maplogTextSecondary)

                        Text(row.value)
                            .font(MaplogFont.callout)
                            .foregroundStyle(Color.maplogTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(MaplogSpacing.cardPadding)
        .maplogCard()
    }

    @ViewBuilder
    private func contentLine(
        _ line: TourismDetailContentLineViewData
    ) -> some View {
        switch line.style {
        case .heading:
            Text(line.text)
                .font(MaplogFont.calloutStrong)
                .foregroundStyle(Color.maplogTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, MaplogSpacing.xSmall)

        case .bullet:
            HStack(alignment: .top, spacing: MaplogSpacing.small) {
                Circle()
                    .fill(Color.maplogPrimary)
                    .frame(width: 6, height: 6)
                    .padding(.top, 8)

                Text(line.text)
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogTextSecondary)
                    .lineSpacing(MaplogSpacing.xxSmall)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .body:
            Text(line.text)
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogTextSecondary)
                .lineSpacing(MaplogSpacing.xxSmall)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
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
    let phoneNumber: String?
    let phoneURL: URL?
    let homepageURL: URL?

    var body: some View {
        if phoneURL != nil || homepageURL != nil {
            HStack(spacing: MaplogSpacing.small) {
                if let phoneNumber, let phoneURL {
                    Link(destination: phoneURL) {
                        Label("전화", systemImage: "phone.fill")
                            .lineLimit(1)
                    }
                    .buttonStyle(
                        MaplogButtonStyle(
                            variant: .secondary,
                            size: .regular,
                            fullWidth: true
                        )
                    )
                    .accessibilityLabel("\(phoneNumber)로 전화")
                }

                if let homepageURL {
                    Link(destination: homepageURL) {
                        Label("홈페이지", systemImage: "safari")
                            .lineLimit(1)
                    }
                    .buttonStyle(
                        MaplogButtonStyle(
                            variant: .secondary,
                            size: .regular,
                            fullWidth: true
                        )
                    )
                    .accessibilityLabel("홈페이지 열기")
                }
            }
        }
    }
}
