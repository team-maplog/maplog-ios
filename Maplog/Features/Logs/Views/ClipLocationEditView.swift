//
//  ClipLocationEditView.swift
//  Maplog
//
//  Created by 한채림 on 8/9/26.
//

import SwiftUI
import UIKit

struct ClipLocationEditView: View {
    @ObservedObject var viewModel: ClipLocationEditViewModel // 부모가 만든 viewModel을 전달받아 관찰만 함
    @Environment(\.dismiss) private var dismiss

    let thumbnailData: Data?
    let onSave: () -> Void

    var body: some View {

        GeometryReader { geometry in
            VStack(spacing: MaplogSpacing.medium) {
                // 지도는 바깥 ScrollView에 넣지 않아 이동·핀치가 화면 스크롤과 경쟁하지 않는다.
                locationMap
                    .frame(height: min(360, max(180, geometry.size.height * 0.48)))

                ScrollView {
                    VStack(alignment: .leading, spacing: MaplogSpacing.section) {
                        clipSummary
                        locationSelectionStatus
                        locationInformation
                    }
                    .padding(.bottom, MaplogSpacing.section)
                }
            }
            .maplogPagePadding()
            .padding(.top, MaplogSpacing.small)
        }
        .navigationTitle("클립 장소 수정")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                MaplogNavigationButton(
                    systemName: "chevron.left",
                    accessibilityLabel: "뒤로 가기"
                ) {
                    dismiss()
                }
            }
        }
        .maplogScreenSurface()
        .maplogNavigationAppearance()
        .safeAreaInset(edge: .bottom) {
            PrimaryActionButton(
                "이 위치로 저장",
                systemImage: "checkmark",
                isEnabled: viewModel.canSave,
                action: onSave
            )
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.vertical, MaplogSpacing.small)
            .background(Color.maplogSurface)
        }
        .task {
            viewModel.resolveInitialLocationIfNeeded()
        }
        .onDisappear {
            viewModel.cancelLocationResolution()
        }
    }

    private var clipSummary: some View {
        HStack(spacing: MaplogSpacing.medium) {
            thumbnail

            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                Text("선택한 클립")
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogTextSecondary)

                Text(viewModel.timeRangeText)
                    .font(MaplogFont.sectionTitle)
                    .monospacedDigit()
                    .foregroundStyle(Color.maplogTextPrimary)

                Text("이 구간에 표시할 장소를 확인해 주세요.")
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(MaplogSpacing.small)
        .maplogCard()
    }

    private var locationMap: some View {
        ClipLocationPickerMap(location: viewModel.mapLocation) { latitude, longitude in
            viewModel.selectLocation(latitude: latitude, longitude: longitude)
        }
        .overlay(alignment: .topLeading) {
            Text("두 손가락으로 확대·축소하고 지도를 움직여 선택하세요")
                .font(MaplogFont.caption)
                .padding(MaplogSpacing.small)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(MaplogSpacing.small)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.xLarge))
        .accessibilityLabel("클립 장소 선택 지도")
    }

    private var locationSelectionStatus: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            if viewModel.selectedLocation == nil {
                Text("촬영 위치가 없어요. 지도에서 장소를 직접 선택해 주세요.")
                    .font(MaplogFont.callout)
                Button("현재 핀 위치 선택") {
                    viewModel.selectLocation(
                        latitude: viewModel.mapLocation.latitude,
                        longitude: viewModel.mapLocation.longitude
                    )
                }
                .buttonStyle(MaplogButtonStyle(variant: .secondary))
            }
            if let error = viewModel.locationResolutionError {
                Text(error.message)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogDanger)
                Button("주소 다시 확인") { viewModel.retryLocationResolution() }
            }
        }
    }

    private var locationInformation: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("선택한 위치")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogTextPrimary)

            MaplogLocationLabel(
                title: viewModel.locationText,
                pinSize: 16
            )
            .font(MaplogFont.bodyStrong)
            .foregroundStyle(Color.maplogTextPrimary)
            .padding(MaplogSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .maplogCard()

            Button("촬영 당시 위치로") {
                viewModel.restoreCapturedLocation()
            }
            .buttonStyle(
                MaplogButtonStyle(
                    variant: .secondary,
                    size: .regular
                )
            )
            .disabled(!viewModel.canRestoreCapturedLocation)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if
            let thumbnailData,
            let image = UIImage(data: thumbnailData)
        {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 112)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MaplogRadius.medium,
                        style: .continuous
                    )
                )
        } else {
            Color.maplogSurfaceRaised
                .frame(width: 88, height: 112)
                .overlay {
                    Image(systemName: "video.fill")
                        .foregroundStyle(Color.maplogTextTertiary)
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MaplogRadius.medium,
                        style: .continuous
                    )
                )
        }
    }
}
