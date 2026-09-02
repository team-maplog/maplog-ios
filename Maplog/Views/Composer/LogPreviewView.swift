import SwiftUI

struct LogPreviewView: View {
    let draft: ComposerDraft
    @Environment(\.dismiss) private var dismiss
    @Environment(\.maplogSelectTab) private var selectTab
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var isPublished = false
    @State private var showsShareSheet = false
    @State private var toastText: String?
    @State private var publishedLog: TravelLog?

    private var displayedPublishedLog: TravelLog {
        publishedLog ?? TravelLog(
            id: "preview-\(draft.displayTitle)",
            title: draft.displayTitle,
            place: draft.displayPlace,
            date: "2026.06",
            note: draft.note,
            imageStyle: draft.imageStyle,
            clips: safeClipCount,
            city: "Seoul"
        )
    }

    private var safeClipCount: Int {
        max(draft.clipCount, 1)
    }

    private var durationText: String {
        "\(safeClipCount)–\(safeClipCount * 2)초"
    }

    private var previewLocationTags: [MaplogDraftLocationTag] {
        if !draft.locationTags.isEmpty {
            return draft.locationTags
        }

        return [
            MaplogDraftLocationTag(
                id: "preview-primary",
                name: draft.displayPlace,
                timeRange: "00:00 - 00:02",
                style: draft.imageStyle
            )
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if isPublished {
                        publishedState
                    } else {
                        reviewState
                    }
                }
                .padding(MaplogSpacing.page)
                .padding(.bottom, isPublished ? 38 : 116)
            }

            if !isPublished {
                reviewBottomBar
            }

            if let toastText {
                Text(toastText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(Color.maplogSurface)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, isPublished ? 26 : 94)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(isPublished ? "게시 완료" : "게시 전 확인")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground))
        .maplogTabBarHidden()
        .sheet(isPresented: $showsShareSheet) {
            PublishedShareSheet(draft: draft) { message in
                showToast(message)
            }
            .presentationDetents([.height(310)])
            .presentationDragIndicator(.visible)
        }
    }

    private var reviewState: some View {
        VStack(alignment: .leading, spacing: 22) {
            CaptureTravelImageView(style: draft.imageStyle, cornerRadius: MaplogRadius.xLarge)
                .frame(height: 330)
                .overlay(alignment: .topTrailing) {
                    Label(durationText, systemImage: "circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, MaplogSpacing.small)
                        .frame(height: 34)
                        .background(.black.opacity(0.62))
                        .clipShape(Capsule())
                        .padding(MaplogSpacing.small)
                }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ChipView(title: draft.mood, isSelected: true)
                    Spacer()
                    Label("\(draft.rating)", systemImage: "star.fill")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                }

                Text(draft.displayTitle)
                    .font(.system(size: 29, weight: .black))
                    .foregroundStyle(Color.maplogInk)

                if draft.displayTitle != draft.displayPlace {
                    MaplogLocationLabel(
                        title: draft.displayPlace,
                        pinSize: 14
                    )
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                }

                Text(draft.note)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
                    .lineSpacing(5)

                HStack(spacing: MaplogSpacing.xSmall) {
                    InfoBadge(title: "전체 공개", systemImage: "eye.fill")
                    InfoBadge(title: "\(safeClipCount)개 클립", systemImage: "play.rectangle.fill")
                }
            }
            .padding(MaplogSpacing.medium)
            .maplogCard()

            VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                SectionHeader(title: "위치 태그", subtitle: "게시 후 장소 상세와 지도에 연결됩니다")
                VStack(spacing: 0) {
                    ForEach(Array(previewLocationTags.enumerated()), id: \.element.id) { index, tag in
                        previewLocationRow(index: index + 1, title: tag.name, time: tag.timeRange)
                        if tag.id != previewLocationTags.last?.id {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .maplogCard()
            }
        }
    }

    private var publishedState: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 20)

            ZStack {
                Circle()
                    .fill(Color.maplogLime.opacity(0.22))
                    .frame(width: 132, height: 132)
                Circle()
                    .fill(Color.maplogLime)
                    .frame(width: 86, height: 86)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(Color.maplogInk)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: MaplogSpacing.xSmall) {
                Text("맵로그가 게시됐어요")
                    .font(.system(size: 27, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                Text("\(displayedPublishedLog.place)의 기록이 내 프로필 로그 목록에 추가되었습니다.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 22)

            CaptureTravelImageView(style: draft.imageStyle, cornerRadius: MaplogRadius.xLarge)
                .frame(height: 220)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(draft.displayTitle)
                            .font(MaplogFont.screenTitle)
                        Text(draft.note)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(2)
                    }
                    .foregroundStyle(.white)
                    .padding(MaplogSpacing.medium)
                }

            VStack(spacing: 10) {
                NavigationLink {
                    MyLogDetailView(log: displayedPublishedLog) { log in
                        sessionStore.deleteLog(log)
                    }
                } label: {
                    Label("내 기록 보기", systemImage: "play.circle.fill")
                        .font(MaplogFont.cardTitle)
                        .foregroundStyle(Color.maplogOnPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button {
                        showsShareSheet = true
                    } label: {
                        Label("공유", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.maplogCanvas)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        selectTab(.home)
                    } label: {
                        Label("홈 피드에서 보기", systemImage: "house.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.maplogCanvas)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    selectTab(.profile)
                } label: {
                    Label("프로필에서 확인", systemImage: "person.crop.circle.fill")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.maplogCanvas)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Label("업로드로 돌아가기", systemImage: "pencil")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.maplogMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var reviewBottomBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("수정하기")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 118, height: 56)
                    .background(Color.maplogCanvas)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                publishCurrentDraft()
            } label: {
                Label("게시 완료", systemImage: "checkmark")
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
    }

    private func previewLocationRow(index: Int, title: String, time: String) -> some View {
        HStack(spacing: MaplogSpacing.small) {
            Text("\(index)")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.maplogOnPrimary)
                .frame(width: 32, height: 32)
                .background(Color.maplogLime.opacity(0.72))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                Text(time)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
            }

            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.maplogLime)
        }
        .padding(14)
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            toastText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeOut(duration: 0.2)) {
                if toastText == text {
                    toastText = nil
                }
            }
        }
    }

    private func publishCurrentDraft() {
        if publishedLog == nil {
            publishedLog = sessionStore.publish(draft: draft)
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            isPublished = true
        }
    }
}

private struct PublishedShareSheet: View {
    let draft: ComposerDraft
    let onAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.large) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("공유하기")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text(draft.displayTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                shareOption(title: "링크", systemImage: "link") {
                    complete("공유 링크를 복사했어요")
                }
                shareOption(title: "스토리", systemImage: "sparkles.rectangle.stack") {
                    complete("스토리 공유 화면을 열었어요")
                }
                shareOption(title: "친구", systemImage: "person.2.fill") {
                    complete("친구에게 보냈어요")
                }
            }

            Button {
                complete("내 지도에 고정했어요")
            } label: {
                Label("내 지도 상단에 고정", systemImage: "pin.fill")
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(MaplogSpacing.xLarge)
    }

    private func shareOption(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(MaplogFont.sectionTitle)
                    .foregroundStyle(Color.maplogPrimary)
                    .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                    .contentShape(Rectangle())
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func complete(_ message: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onAction(message)
        }
    }
}
