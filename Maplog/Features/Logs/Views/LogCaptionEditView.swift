import SwiftUI
import UIKit

/// 상세 화면과 분리된 로그 수정 화면입니다. 장소는 읽기 전용으로 표시합니다.
struct LogCaptionEditView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var caption: String
    let selectedTags: Set<LogTag>

    let thumbnailData: Data?
    let address: String
    let isSaving: Bool
    let formMessage: String?
    let captionMessage: String?
    let recoveryAction: ErrorPresentation.RecoveryAction?
    let onTagToggle: (LogTag) -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onSignIn: () -> Void

    private var canSave: Bool {
        !isSaving
            && !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && caption.count <= 1_000
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                LogCaptionEditPreview(thumbnailData: thumbnailData)
                captionEditor
                tagEditor
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
        HStack(spacing: MaplogSpacing.small) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                .foregroundStyle(Color.maplogMuted)

            Text("장소")
                .font(MaplogFont.body)
                .foregroundStyle(Color.maplogMuted)

            Text(address)
                .font(MaplogFont.bodyStrong)
                .foregroundStyle(Color.maplogInk)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.top, MaplogSpacing.medium)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.maplogLine)
                .frame(height: 1)
        }
        .accessibilityHint("현재 장소 수정은 지원하지 않습니다")
    }

    private var tagEditor: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("태그")
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogMuted)

            LogTagPicker(
                selectedTags: selectedTags,
                onToggle: onTagToggle
            )
        }
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
