//
//  HomeMapPanel.swift
//  Maplog
//
//  Created by 한채림 on 8/17/26.
//

import SwiftUI

struct HomeMapPanel: View {
    @ObservedObject var viewModel: HomeMapPanelViewModel
    let onRequestSignIn: () -> Void

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
        .background(Color.black)
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
                }
            )

            VStack(spacing: 12) {
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

                if let selectedPoint = viewModel.selectedPoint {
                    selectedPlaceCard(
                        selectedPoint
                    )
                }
            }
            .padding(.bottom, 112)
        }
    }

    private func selectedPlaceCard(
        _ point: HomeMapRoutePointViewData
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(point.sequence)번째 장소")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Color.maplogLime,
                        in: Capsule()
                    )

                Spacer()

                Image(systemName: "play.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.maplogInk)

                Text(videoTimeText(
                    milliseconds: point.startTimeMillis
                ))
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.maplogInk)
            }

            Text(point.placeName)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.maplogInk)
                .lineLimit(1)

            Label(
                point.address,
                systemImage: "mappin.and.ellipse"
            )
            .font(.subheadline)
            .foregroundStyle(Color.maplogMuted)
            .lineLimit(1)
        }
        .padding(18)
        .background(
            Color.white.opacity(0.96),
            in: RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(point.sequence)번째 장소, \(point.placeName), \(point.address)"
        )
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
                    .tint(.white)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }

            if let actionTitle,
               let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.maplogLime)
                    .foregroundStyle(Color.maplogInk)
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
                        ? Color.maplogInk
                        : .white
                )
                .frame(width: 24, height: 24)
                .background(
                    isSelected
                        ? Color.maplogLime
                        : .white.opacity(0.18),
                    in: Circle()
                )

            Text(point.placeName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            isSelected
                ? .black.opacity(0.82)
                : .black.opacity(0.48),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .strokeBorder(
                    isSelected
                        ? Color.maplogLime
                        : .white.opacity(0.22),
                    lineWidth: 1
                )
        }
        .accessibilityLabel(
            "\(point.sequence)번째 장소, \(point.placeName)"
        )
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }
}
