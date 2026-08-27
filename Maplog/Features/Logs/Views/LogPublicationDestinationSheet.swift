//
//  LogPublicationDestinationSheet.swift
//  Maplog
//

import SwiftUI

struct LogPublicationDestinationSheet: View {
    let videoFileURL: URL
    let canComplete: (Set<LogPublicationDestination>) -> Bool
    let isCompleting: Bool
    let onComplete: (Set<LogPublicationDestination>) -> Void

    @State private var destinations: Set<LogPublicationDestination> = [.maplog]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MaplogSpacing.section) {
                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                    Text("어디에 남길까요?")
                        .font(MaplogFont.screenTitle)

                    Text("Maplog에 공유하거나, 내 사진 앱에 보관할 수 있어요.")
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogTextSecondary)
                }

                VStack(spacing: MaplogSpacing.xSmall) {
                    ForEach(LogPublicationDestination.allCases) { destination in
                        destinationRow(destination)
                    }
                }

                Divider()

                ShareLink(item: videoFileURL) {
                    Label("다른 앱으로 공유", systemImage: "square.and.arrow.up")
                        .font(MaplogFont.calloutStrong)
                        .foregroundStyle(Color.maplogTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(MaplogSpacing.medium)
                        .background(
                            Color.maplogSurfaceRaised,
                            in: RoundedRectangle(
                                cornerRadius: MaplogRadius.medium,
                                style: .continuous
                            )
                        )
                }

                Spacer()

                PrimaryActionButton(
                    actionTitle,
                    systemImage: isCompleting ? nil : "checkmark",
                    isEnabled: canComplete(destinations) && !isCompleting
                ) {
                    onComplete(destinations)
                }
            }
            .padding(MaplogSpacing.page)
            .navigationTitle("발행 옵션")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func destinationRow(
        _ destination: LogPublicationDestination
    ) -> some View {
        let isSelected = destinations.contains(destination)

        return Button {
            if isSelected {
                destinations.remove(destination)
            } else {
                destinations.insert(destination)
            }
        } label: {
            HStack(spacing: MaplogSpacing.medium) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(
                        isSelected ? Color.maplogInk : Color.maplogTextSecondary
                    )
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.title)
                        .font(MaplogFont.calloutStrong)
                        .foregroundStyle(Color.maplogTextPrimary)

                    Text(destination.detail)
                        .font(MaplogFont.caption)
                        .foregroundStyle(Color.maplogTextSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        isSelected ? Color.maplogPrimary : Color.maplogLine
                    )
            }
            .padding(MaplogSpacing.medium)
            .background(
                isSelected ? Color.maplogLime.opacity(0.16) : Color.maplogSurfaceRaised,
                in: RoundedRectangle(
                    cornerRadius: MaplogRadius.medium,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: MaplogRadius.medium,
                    style: .continuous
                )
                .stroke(
                    isSelected ? Color.maplogPrimary.opacity(0.55) : Color.maplogLine,
                    lineWidth: 1
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "선택됨" : "선택되지 않음")
    }

    private var actionTitle: String {
        if isCompleting {
            return "처리 중…"
        }

        switch destinations {
        case [.maplog, .photoLibrary]:
            return "발행하고 저장하기"
        case [.maplog]:
            return "Maplog에 발행하기"
        case [.photoLibrary]:
            return "사진 앱에 저장하기"
        default:
            return "저장 위치를 선택해 주세요"
        }
    }
}
