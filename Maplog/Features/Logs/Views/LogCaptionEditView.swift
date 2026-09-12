import SwiftUI
import UIKit

/// 캡션과 장소 초안을 편집하고 완료할 때 함께 저장합니다.
struct LogCaptionEditView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var caption: String

    let thumbnailData: Data?
    let address: String
    let clips: [LogReelClip]
    let clipLocations: [Int64: LogReelLocation]
    let onEditRepresentativeLocation: () -> Void
    let onEditClipLocation: (LogReelClip) -> Void
    let allowsEmptyCaption: Bool
    let isSaving: Bool
    let formMessage: String?
    let captionMessage: String?
    let recoveryAction: ErrorPresentation.RecoveryAction?
    let onSave: () -> Void
    let onCancel: () -> Void
    let onSignIn: () -> Void

    private var canSave: Bool {
        !isSaving
            && (allowsEmptyCaption || !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            && caption.count <= 1_000
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                LogCaptionEditPreview(thumbnailData: thumbnailData)
                captionEditor
                placeRow
            }
            .maplogPagePadding()
            .padding(.top, MaplogSpacing.pageTop)
            .maplogListBottomPadding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("게시물 수정")
        .navigationBarTitleDisplayMode(.inline)
        .maplogScreenSurface()
        .maplogNavigationAppearance()
        .interactiveDismissDisabled(isSaving)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소", action: cancel)
                    .disabled(isSaving)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onSave) {
                    if isSaving {
                        ProgressView()
                            .tint(Color.maplogOlive)
                    } else {
                        Text("완료")
                    }
                }
                .font(MaplogFont.calloutStrong)
                .foregroundStyle(Color.maplogOlive)
                .disabled(!canSave)
            }
        }
    }

    private var captionEditor: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("캡션")
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogMuted)

            ZStack(alignment: .topLeading) {
                if caption.isEmpty {
                    Text("영상과 함께 남기고 싶은 이야기를 적어보세요.")
                        .font(MaplogFont.body)
                        .foregroundStyle(Color.maplogSubtle)
                        .padding(.top, MaplogSpacing.xxxSmall)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $caption)
                    .font(MaplogFont.body)
                    .foregroundStyle(Color.maplogInk)
                    .frame(minHeight: 180)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, -MaplogSpacing.xxxSmall)
                    .accessibilityLabel("캡션")
            }

            HStack {
                if let captionMessage {
                    Text(captionMessage)
                        .foregroundStyle(Color.maplogDanger)
                } else if caption.count > 1_000 {
                    Text("캡션은 1,000자 이하로 입력해 주세요.")
                        .foregroundStyle(Color.maplogDanger)
                } else {
                    Text("최대 1,000자")
                        .foregroundStyle(Color.maplogMuted)
                }

                Spacer()

                Text("\(caption.count)/1000")
                    .monospacedDigit()
                    .foregroundStyle(Color.maplogMuted)
            }
            .font(MaplogFont.caption)

            if let formMessage {
                LogCaptionEditError(
                    message: formMessage,
                    recoveryAction: recoveryAction,
                    onSave: onSave,
                    onSignIn: onSignIn
                )
            }
        }
    }

    private var placeRow: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            Divider()
            Text("장소").font(MaplogFont.bodyStrong)
            locationButton(title: "대표 장소", address: address, action: onEditRepresentativeLocation)
            Text("대표 장소는 게시물 목록에 표시돼요.")
                .font(MaplogFont.caption).foregroundStyle(Color.maplogMuted)

            if !clips.isEmpty {
                Text("영상 속 장소").font(MaplogFont.bodyStrong)
                Text("장소를 바꾸면 지도에 표시되는 경로도 바뀌어요.")
                    .font(MaplogFont.caption).foregroundStyle(Color.maplogMuted)
                ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                    let location = clipLocations[clip.id] ?? clip.location
                    locationButton(
                        title: "\(index + 1). \(location.name ?? "장소")",
                        address: location.address
                    ) { onEditClipLocation(clip) }
                }
            }
        }
        .disabled(isSaving)
    }

    private func locationButton(title: String, address: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: MaplogSpacing.small) {
                MaplogPinGlyphIcon(size: MaplogSize.iconMedium)
                    .foregroundStyle(Color.maplogOlive)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(MaplogFont.bodyStrong).foregroundStyle(Color.maplogInk)
                    Text(address).font(MaplogFont.caption).foregroundStyle(Color.maplogMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text("변경").font(MaplogFont.caption).foregroundStyle(Color.maplogOlive)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.maplogMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .padding(MaplogSpacing.medium)
            .background(Color.maplogSurfaceRaised, in: RoundedRectangle(cornerRadius: MaplogRadius.medium))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("지도에서 위치를 움직이거나 검색해 변경합니다")
    }

    private func cancel() {
        onCancel()
        dismiss()
    }
}

private struct LogCaptionEditPreview: View {
    let thumbnailData: Data?

    /// 편집 시에는 입력 중인 캡션을 함께 확인하는 일이 더 중요하므로,
    /// 세로 영상의 맥락을 유지한 작은 미리보기 카드만 사용합니다.
    private let previewWidth: CGFloat = 88
    private let previewHeight: CGFloat = 132

    var body: some View {
        Group {
            if let thumbnailData,
               let image = UIImage(data: thumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.maplogCanvas
                    .overlay {
                        Image(systemName: "video.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color.maplogMuted)
                    }
            }
        }
        .frame(width: previewWidth, height: previewHeight)
        .clipShape(RoundedRectangle(
            cornerRadius: MaplogRadius.xLarge,
            style: .continuous
        ))
        .overlay(alignment: .bottomLeading) {
            Image(systemName: "play.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.black.opacity(0.58), in: Circle())
                .padding(MaplogSpacing.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("영상 미리보기")
    }
}

private struct LogCaptionEditError: View {
    let message: String
    let recoveryAction: ErrorPresentation.RecoveryAction?
    let onSave: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            Text(message)
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogDanger)

            switch recoveryAction {
            case .retry:
                Button("다시 시도", action: onSave)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogOlive)

            case .signIn:
                Button("다시 로그인", action: onSignIn)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogOlive)

            case .some(.none), .none:
                EmptyView()
            }
        }
    }
}
