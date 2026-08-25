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
            .background(Color.white.ignoresSafeArea())
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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TourismDetailPhotoCarousel(
                    heroImageURL: detail.heroImageURL,
                    images: detail.images,
                    onBack: onBack
                )
                // 상태바 영역은 비워 두고, 사진은 그 아래에서 시작한다.
                // 배터리·시간 아이콘이 사진 배경에 묻히지 않도록 하는 여백이다.
                .padding(.top, MaplogSpacing.medium)

                VStack(alignment: .leading, spacing: MaplogSpacing.xxLarge) {
                    TourismDetailTitleSection(detail: detail)

                    TourismDetailActionSection(
                        title: detail.title,
                        coordinate: detail.coordinate,
                        phoneNumber: detail.phoneNumber,
                        phoneURL: detail.phoneURL,
                        homepageURL: detail.homepageURL
                    )

                    if let overviewText = detail.overviewText {
                        TourismDetailOverviewSection(text: overviewText)
                    }

                    if let quickInformationSection {
                        TourismDetailQuickInfoSection(rows: quickInformationSection.rows)
                    }

                    if let coordinate = detail.coordinate {
                        TourismDetailLocationPreviewSection(
                            title: detail.title,
                            addressText: detail.addressText,
                            coordinate: coordinate
                        )
                    }

                    if !detail.programLines.isEmpty {
                        TourismDetailProgramSection(lines: detail.programLines)
                    }

                    ForEach(detailedInformationSections) { section in
                        TourismDetailInformationSection(
                            title: section.title,
                            rows: section.rows,
                            layout: .detail
                        )
                    }

                    if let organizerInformationSection {
                        TourismDetailOrganizerSection(rows: organizerInformationSection.rows)
                    }

                    if !detail.repeatInfoItems.isEmpty {
                        TourismDetailRepeatInfoSection(items: detail.repeatInfoItems)
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
                .padding(.horizontal, 24)
                .padding(.top, MaplogSpacing.xxLarge)
            }
            .padding(.bottom, MaplogSpacing.xxLarge)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let coordinate = detail.coordinate {
                TourismDetailDirectionsBar(
                    title: detail.title,
                    coordinate: coordinate
                )
            }
        }
    }

}

private struct TourismDetailTitleSection: View {
    let detail: TourismDetailViewData

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            HStack(spacing: MaplogSpacing.xSmall) {
                Text(detail.categoryText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.maplogTextPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.maplogPrimary, in: Capsule())

                if let statusText = detail.statusText {
                    Text(statusText)
                        .font(MaplogFont.caption)
                        .foregroundStyle(Color.maplogTextSecondary)
                }
            }

            Text(detail.title)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(Color.maplogTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if detail.periodText != nil || detail.addressText != nil || detail.regionText != nil {
                VStack(spacing: 0) {
                    if let periodText = detail.periodText {
                        TourismDetailPrimaryMetaRow(
                            text: periodText,
                            systemImage: "calendar"
                        )

                        if detail.addressText != nil || detail.regionText != nil {
                            Divider()
                        }
                    }

                    if let addressText = detail.addressText ?? detail.regionText {
                        TourismDetailPrimaryMetaRow(
                            text: addressText,
                            systemImage: "mappin.and.ellipse"
                        )
                    }
                }
            }
        }
    }
}

private struct TourismDetailPrimaryMetaRow: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .frame(width: 20)
        }
        .font(.system(size: 15))
        .foregroundStyle(Color.maplogTextPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, MaplogSpacing.small)
    }
}

private struct TourismDetailOverviewSection: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("소개")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Color.maplogTextPrimary)

            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.maplogTextSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TourismDetailQuickInfoSection: View {
    let rows: [TourismDetailInfoRowViewData]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: MaplogSpacing.small) {
                    Image(systemName: iconName(for: row.id))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.maplogTextPrimary)
                        .frame(width: 26)

                    Text(row.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.maplogTextPrimary)
                        .frame(width: 62, alignment: .leading)

                    Text(row.value)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.maplogTextPrimary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, MaplogSpacing.small)

                if row.id != rows.last?.id {
                    Divider()
                }
            }
        }
        .padding(.horizontal, MaplogSpacing.medium)
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.xLarge, style: .continuous))
    }

    private func iconName(for rowID: String) -> String {
        switch rowID {
        case "period", "date", "useTime", "openingHours":
            return "calendar"
        case "address", "location", "place":
            return "mappin.and.ellipse"
        case "fee", "price", "usageFee":
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
    let title: String
    let coordinate: TourismDetailCoordinateViewData?
    let phoneNumber: String?
    let phoneURL: URL?
    let homepageURL: URL?

    var body: some View {
        if coordinate != nil || phoneURL != nil || homepageURL != nil {
            HStack(spacing: MaplogSpacing.small) {
                if let coordinate {
                    NavigationLink {
                        TourismLocationMapView(
                            title: title,
                            coordinate: coordinate
                        )
                    } label: {
                        TourismDetailActionLabel(
                            title: "지도 보기",
                            systemImage: "map"
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("\(title) 위치 지도 보기")
                }

                if let homepageURL {
                    Link(destination: homepageURL) {
                        TourismDetailActionLabel(
                            title: "홈페이지",
                            systemImage: "globe"
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("홈페이지 열기")
                }

                // 홈페이지가 없는 관광지에서는 연락 수단을 대신 보여 준다.
                if homepageURL == nil, let phoneNumber, let phoneURL {
                    Link(destination: phoneURL) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: MaplogSize.iconSmall, weight: .semibold))
                            .foregroundStyle(Color.maplogTextPrimary)
                            .frame(
                                width: MaplogSize.minimumTapTarget,
                                height: MaplogSize.minimumTapTarget
                            )
                            .background(Color.maplogSurfaceRaised, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(Color.maplogBorder, lineWidth: 1)
                            }
                    }
                    .accessibilityLabel("\(phoneNumber)로 전화")
                }
            }
        }
    }
}

private struct TourismDetailActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.maplogTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Color.white,
                in: RoundedRectangle(
                    cornerRadius: MaplogRadius.large,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: MaplogRadius.large,
                    style: .continuous
                )
                .stroke(Color.maplogBorder, lineWidth: 1)
            }
    }
}

private struct TourismDetailDirectionsBar: View {
    let title: String
    let coordinate: TourismDetailCoordinateViewData

    var body: some View {
        NavigationLink {
            TourismLocationMapView(title: title, coordinate: coordinate)
        } label: {
            Label("길찾기", systemImage: MaplogSymbol.directions)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.maplogTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.maplogPrimary, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.top, MaplogSpacing.small)
        .padding(.bottom, MaplogSpacing.xSmall)
        .background(Color.white)
        .overlay(alignment: .top) {
            Divider()
        }
        .accessibilityLabel("\(title) 길찾기")
    }
}
