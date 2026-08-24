import SwiftUI

/// iOS가 위치를 정하는 confirmationDialog 대신 화면 중앙에 표시하는 삭제 확인 창입니다.
struct LogDeleteConfirmationOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isDeleting: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Button(action: onCancel) {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            .accessibilityLabel("삭제 확인 닫기")

            VStack(spacing: MaplogSpacing.medium) {
                Image(systemName: "trash")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.maplogDanger)
                    .frame(width: 48, height: 48)
                    .background(
                        Color.maplogDanger.opacity(0.12),
                        in: Circle()
                    )

                VStack(spacing: MaplogSpacing.xSmall) {
                    Text("맵로그를 삭제할까요?")
                        .font(MaplogFont.sectionTitle)
                        .foregroundStyle(Color.maplogInk)

                    Text("삭제한 맵로그는 복구할 수 없어요.")
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogMuted)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: MaplogSpacing.xSmall) {
                    Button("취소", action: onCancel)
                        .buttonStyle(
                            MaplogButtonStyle(
                                variant: .secondary,
                                size: .regular,
                                fullWidth: true
                            )
                        )
                        .disabled(isDeleting)

                    Button(action: onConfirm) {
                        if isDeleting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("삭제")
                        }
                    }
                    .buttonStyle(
                        MaplogButtonStyle(
                            variant: .destructive,
                            size: .regular,
                            fullWidth: true
                        )
                    )
                    .disabled(isDeleting)
                    .accessibilityIdentifier("log.detail.confirmDelete")
                }
            }
            .padding(MaplogSpacing.large)
            .frame(maxWidth: 320)
            .background(
                Color.maplogSurface,
                in: RoundedRectangle(
                    cornerRadius: MaplogRadius.xLarge,
                    style: .continuous
                )
            )
            .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 10)
            .padding(.horizontal, MaplogSpacing.page)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: isDeleting
        )
    }
}
