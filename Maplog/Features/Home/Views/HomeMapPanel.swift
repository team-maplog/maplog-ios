//
//  HomeMapPanel.swift
//  Maplog
//
//  Created by 한채림 on 8/17/26.
//

import SwiftUI
import UIKit

struct HomeMapPanel: View {
    @ObservedObject var viewModel: HomeMapPanelViewModel
    let onRequestSignIn: () -> Void
    let onPlayRoutePoint: (HomeMapRoutePlaybackRequest) -> Void

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                statusView(
                    systemImage: "map",
                    title: "릴스를 선택해 주세요",
                    message: "릴스 화면에서 지도를 열면 장소 경로를 보여드릴게요.",
                    actionTitle: nil,
                    action: nil
                )

            case .loading:
                statusView(
                    systemImage: "map",
                    title: "경로를 불러오는 중이에요",
                    message: nil,
                    actionTitle: nil,
                    action: nil,
                    showsProgress: true
                )

            case let .content(route):
                routeContent(route)

            case .empty:
                statusView(
                    systemImage: "mappin.slash",
                    title: "등록된 장소가 없어요",
                    message: "이 로그에는 지도에 표시할 장소 정보가 없어요.",
                    actionTitle: nil,
                    action: nil
                )

            case let .failed(presentation):
                statusView(
                    systemImage: "exclamationmark.triangle",
                    title: "경로를 불러오지 못했어요",
                    message: presentation.message,
                    actionTitle: actionTitle(
                        for: presentation.recoveryAction
                    ),
                    action: {
                        handleRecoveryAction(
                            presentation.recoveryAction
                        )
                    }
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        // 릴스 위에서 열려도 지도 패널은 라이트 톤을 유지함.
        .background(Color.maplogMapLightCanvas)
        .preferredColorScheme(.light)
        .ignoresSafeArea()
    }

    private func routeContent(
        _ route: HomeMapRouteViewData
    ) -> some View {
        ZStack(alignment: .bottom) {
            /// 다음 5단계에서 이 자리를 실제 Kakao 지도 Canvas로 교체합니다.
            LogRouteKakaoMap(
                points: route.points,
                selectedPointID: viewModel.selectedPointID,
                onPointSelected: { pointID in
                    viewModel.selectPoint(
                        id: pointID
                    )
                },
                thumbnailDataByPointID: viewModel.thumbnailDataByPointID
            )

            VStack(spacing: 8) {
                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    HStack(spacing: 8) {
                        ForEach(route.points) { point in
                            Button {
                                viewModel.selectPoint(
                                    id: point.id
                                )
                            } label: {
                                HomeMapRoutePointChip(
                                    point: point,
                                    isSelected: viewModel.selectedPointID
                                        == point.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                placeCardPager(route)
            }
            .padding(.bottom, 112)
        }
        .task(id: route.logID) {
            await viewModel.loadThumbnails(
                for: route
            )
        }
    }

    private func placeCardPager(
        _ route: HomeMapRouteViewData
    ) -> some View {
        TabView(
            selection: selectedPointBinding(
                for: route
            )
        ) {
            ForEach(route.points) { point in
                selectedPlaceCard(
                    point,
                    logID: route.logID,
                    thumbnailData: viewModel.thumbnailDataByPointID[
                        point.id
                    ],
                    isLoadingThumbnail: viewModel.isLoadingThumbnail(
                        for: point.id
                    )
                )
                .tag(point.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 142)
        .accessibilityLabel("장소 카드")
    }

    private func selectedPointBinding(
        for route: HomeMapRouteViewData
    ) -> Binding<Int64> {
        let fallbackID = route.points[0].id

        return Binding(
            get: {
                viewModel.selectedPointID ?? fallbackID
            },
            set: { pointID in
                viewModel.selectPoint(
                    id: pointID
                )
            }
        )
    }

    private func selectedPlaceCard(
        _ point: HomeMapRoutePointViewData,
        logID: Int64,
        thumbnailData: Data?,
        isLoadingThumbnail: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(point.sequence)번째 장소")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.maplogOnPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Color.maplogLime,
                        in: Capsule()
                    )

                Spacer()

                Image(systemName: "play.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.maplogMapLightTextPrimary)

                Text(
                    videoTimeText(
                        milliseconds: point.startTimeMillis
                    )
                )
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.maplogMapLightTextPrimary)
            }

            HStack(alignment: .top, spacing: 8) {
                routePointThumbnail(
                    data: thumbnailData,
                    isLoading: isLoadingThumbnail
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(point.placeName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.maplogMapLightTextPrimary)
                        .lineLimit(1)

                    MaplogLocationLabel(
                        title: point.address,
                        pinSize: 14
                    )
                    .font(.caption)
                    .foregroundStyle(Color.maplogMapLightTextSecondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            Button {
                onPlayRoutePoint(
                    HomeMapRoutePlaybackRequest(
                        logID: logID,
                        startTimeMillis: point.startTimeMillis
                    )
                )
            } label: {
                Label(
                    "\(videoTimeText(milliseconds: point.startTimeMillis))부터 영상에서 보기",
                    systemImage: "play.fill"
                )
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.maplogOnPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Color.maplogLime,
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("릴스 영상의 해당 장소가 시작되는 시점부터 재생합니다")
        }
        .padding(12)
        .background(
            Color.maplogMapLightSurface,
            in: RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func routePointThumbnail(
        data: Data?,
        isLoading: Bool
    ) -> some View {
        Group {
            if let data,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()

            } else if isLoading {
                ZStack {
                    Color.maplogMapLightSurfaceRaised

                    ProgressView()
                        .tint(Color.maplogPrimary)
                }

            } else {
                ZStack {
                    Color.maplogMapLightSurfaceRaised

                    Image(systemName: "photo")
                        .foregroundStyle(Color.maplogMapLightTextSecondary)
                }
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
            .stroke(
                Color.maplogLime,
                lineWidth: 1
            )
        }
    }

    private func statusView(
        systemImage: String,
        title: String,
        message: String?,
        actionTitle: String?,
        action: (() -> Void)?,
        showsProgress: Bool = false
    ) -> some View {
        VStack(spacing: 14) {
            if showsProgress {
                ProgressView()
                    .tint(Color.maplogPrimary)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.maplogMapLightTextPrimary)
            }

            Text(title)
                .font(.headline)
                .foregroundStyle(Color.maplogMapLightTextPrimary)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.maplogMapLightTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle,
               let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.maplogLime)
                    .foregroundStyle(Color.maplogMapLightTextPrimary)
                    .padding(.top, 4)
            }
        }
        .padding(28)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    private func actionTitle(
        for recoveryAction: ErrorPresentation.RecoveryAction
    ) -> String? {
        switch recoveryAction {
        case .retry:
            return "다시 시도"

        case .signIn:
            return "다시 로그인"

        case .none:
            return nil
        }
    }

    private func handleRecoveryAction(
        _ recoveryAction: ErrorPresentation.RecoveryAction
    ) {
        switch recoveryAction {
        case .retry:
            Task {
                await viewModel.retry()
            }

        case .signIn:
            onRequestSignIn()

        case .none:
            break
        }
    }

    private func videoTimeText(
        milliseconds: Int64
    ) -> String {
        let totalSeconds = max(
            0,
            milliseconds / 1_000
        )

        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return String(
            format: "%02lld:%02lld",
            minutes,
            seconds
        )
    }
}

private struct HomeMapRoutePointChip: View {
    let point: HomeMapRoutePointViewData
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("\(point.sequence)")
                .font(.caption.weight(.bold))
                .foregroundStyle(
                    isSelected
                        ? Color.maplogMapLightTextPrimary
                        : Color.maplogMapLightTextSecondary
                )
                .frame(width: 20, height: 20)
                .background(
                    isSelected
                        ? Color.maplogLime
                        : Color.maplogMapLightSurfaceRaised,
                    in: Circle()
                )

            Text(point.placeName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.maplogMapLightTextPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            isSelected
                ? Color.maplogLime.opacity(0.24)
                : Color.maplogMapLightSurface,
            in: Capsule()
        )
        .overlay {
            Capsule()
                .strokeBorder(
                    isSelected
                        ? Color.maplogLime
                        : Color.maplogMapLightBorder,
                    lineWidth: 1
                )
        }
        .frame(minHeight: MaplogSize.minimumTapTarget)
        .contentShape(Rectangle())
        .accessibilityLabel(
            "\(point.sequence)번째 장소, \(point.placeName)"
        )
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }
}
