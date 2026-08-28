import PhotosUI
import SwiftUI
import UIKit

struct VlogCommentsSheet: View {
    let post: VlogPost

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @FocusState private var isComposerFocused: Bool
    @State private var draft = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var attachmentData: Data?
    @State private var replyTarget: VlogComment?
    @State private var likedCommentIDs: Set<String> = []
    @State private var localReplies: [String: [VlogComment]] = [:]
    @State private var expandedReplyIDs: Set<String> = []

    private let avatarLetters = ["채", "민", "서", "준", "아"]

    private var baseCommentCount: Int {
        Int(post.comments.filter(\.isNumber)) ?? 0
    }

    private var comments: [VlogComment] {
        sessionStore.vlogComments(for: post.id) + defaultComments
    }

    private var defaultComments: [VlogComment] {
        [
            VlogComment(id: "\(post.id)-default-1", author: "traveler_min", body: "여기 루트 그대로 따라가도 좋겠어요.", timeText: "1분", isMine: false),
            VlogComment(id: "\(post.id)-default-2", author: "route.collector", body: "카페 위치 저장했습니다. 주말에 가볼게요.", timeText: "2분", isMine: false),
            VlogComment(id: "\(post.id)-default-3", author: "seoul.walker", body: "영상 분위기랑 장소가 잘 맞네요.", timeText: "3분", isMine: false)
        ]
    }

    private var seededReplies: [String: [VlogComment]] {
        guard let firstComment = defaultComments.first else { return [:] }
        return [
            firstComment.id: [
                VlogComment(
                    id: "\(post.id)-seeded-reply-1",
                    author: "maplover",
                    body: "저도 다음 주에 이 코스로 걸어보려고요.",
                    timeText: "방금 전",
                    isMine: false
                )
            ]
        ]
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachmentData != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: MaplogSpacing.medium) {
                        ForEach(Array(comments.enumerated()), id: \.element.id) { index, comment in
                            commentRow(comment, index: index)
                        }
                    }
                    .padding(.horizontal, MaplogSpacing.xLarge)
                    .padding(.top, MaplogSpacing.xLarge + MaplogSpacing.xxSmall)
                    .padding(.bottom, MaplogSpacing.xLarge)
                }
                .scrollDismissesKeyboard(.interactively)

                sheetDragHandle
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .background(Color.maplogSurface)
        .onChange(of: selectedPhotoItem) { _, newItem in
            loadSelectedPhoto(newItem)
        }
    }

    private var sheetDragHandle: some View {
        Capsule()
            .fill(Color.maplogMuted.opacity(0.45))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, MaplogSpacing.xSmall)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func commentRow(_ comment: VlogComment, index: Int) -> some View {
        let replies = replies(for: comment)
        let isExpanded = expandedReplyIDs.contains(comment.id)

        return VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            HStack(alignment: .top, spacing: MaplogSpacing.small) {
                avatar(for: comment, index: index, size: MaplogSize.minimumTapTarget)

                VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                    HStack(alignment: .firstTextBaseline, spacing: MaplogSpacing.xxSmall) {
                        Text(comment.author)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.maplogInk)
                        Text(comment.timeText)
                            .font(.caption)
                            .foregroundStyle(Color.maplogMuted)
                    }
                    .padding(.bottom, MaplogSpacing.xxSmall)

                    VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                        if !comment.body.isEmpty {
                            Text(comment.body)
                                .font(.body)
                                .foregroundStyle(Color.maplogInk)
                                .lineSpacing(MaplogSpacing.xxxSmall)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let attachmentData = comment.attachmentData {
                            VlogCommentAttachmentImage(data: attachmentData)
                                .frame(width: 172, height: 132)
                                .padding(.top, MaplogSpacing.xxSmall)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, MaplogSize.minimumTapTarget)
                    .overlay(alignment: .topTrailing) {
                        commentLikeButton(for: comment)
                    }

                    HStack(spacing: MaplogSpacing.small) {
                        Button {
                            startReply(to: comment)
                        } label: {
                            Text("답글 달기")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.maplogMuted)
                                .frame(minHeight: 32, alignment: .topLeading)
                        }
                        .buttonStyle(MaplogPressFeedbackStyle())
                        .accessibilityLabel("\(comment.author)에게 답글 달기")

                        if !replies.isEmpty {
                            Button {
                                toggleReplies(for: comment.id, expanded: isExpanded)
                            } label: {
                                Label(
                                    isExpanded ? "답글 숨기기" : "답글 \(replies.count)개 보기",
                                    systemImage: isExpanded ? "chevron.up" : "chevron.down"
                                )
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.maplogOlive)
                                .frame(minHeight: 32, alignment: .topLeading)
                            }
                            .buttonStyle(MaplogPressFeedbackStyle())
                        }
                    }
                }

            }

            if isExpanded {
                VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
                    ForEach(replies) { reply in
                        replyRow(reply)
                    }
                }
                .padding(.leading, MaplogSize.minimumTapTarget + MaplogSpacing.small)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func replyRow(_ reply: VlogComment) -> some View {
        HStack(alignment: .top, spacing: MaplogSpacing.small) {
            avatar(for: reply, index: 0, size: 32)

            VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                HStack(alignment: .firstTextBaseline, spacing: MaplogSpacing.xxSmall) {
                    Text(reply.author)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.maplogInk)
                    Text(reply.timeText)
                        .font(.caption2)
                        .foregroundStyle(Color.maplogMuted)
                }
                .padding(.bottom, MaplogSpacing.xxxSmall)

                VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                    if !reply.body.isEmpty {
                        Text(reply.body)
                            .font(.callout)
                            .foregroundStyle(Color.maplogInk)
                            .lineSpacing(MaplogSpacing.xxxSmall)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let attachmentData = reply.attachmentData {
                        VlogCommentAttachmentImage(data: attachmentData)
                            .frame(width: 132, height: 104)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, MaplogSize.minimumTapTarget)
                .overlay(alignment: .topTrailing) {
                    commentLikeButton(for: reply, compact: true)
                }
            }
        }
    }

    @ViewBuilder
    private func avatar(for comment: VlogComment, index: Int, size: CGFloat) -> some View {
        if comment.isMine {
            Image("home_profile_avatar")
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .accessibilityHidden(true)
        } else {
            Circle()
                .fill(Color.maplogCanvas)
                .frame(width: size, height: size)
                .overlay {
                    Text(avatarLetters[index % avatarLetters.count])
                        .font(.system(size: size * 0.36, weight: .bold))
                        .foregroundStyle(Color.maplogOlive)
                }
                .accessibilityHidden(true)
        }
    }

    private func commentLikeButton(for comment: VlogComment, compact: Bool = false) -> some View {
        let isLiked = likedCommentIDs.contains(comment.id)
        let count = baseLikeCount(for: comment) + (isLiked ? 1 : 0)

        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                if isLiked {
                    likedCommentIDs.remove(comment.id)
                } else {
                    likedCommentIDs.insert(comment.id)
                }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: compact ? 15 : 18, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font((compact ? Font.caption2 : Font.caption).weight(.semibold))
                }
            }
            .foregroundStyle(isLiked ? Color.maplogOlive : Color.maplogMuted)
            .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(MaplogPressFeedbackStyle())
        .accessibilityLabel(isLiked ? "댓글 좋아요 취소" : "댓글 좋아요")
        .accessibilityValue(count > 0 ? "\(count)개" : "좋아요 없음")
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            if let replyTarget {
                HStack(spacing: MaplogSpacing.xSmall) {
                    Text("@\(replyTarget.author)님에게 답글 작성 중")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.maplogOlive)
                    Spacer(minLength: 0)
                    Button("취소") {
                        self.replyTarget = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.maplogMuted)
                    .buttonStyle(MaplogPressFeedbackStyle())
                    .accessibilityLabel("답글 취소")
                }
            }

            if let attachmentData {
                HStack(spacing: MaplogSpacing.small) {
                    VlogCommentAttachmentImage(data: attachmentData)
                        .frame(width: 52, height: 52)

                    Text("사진 1장 첨부됨")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.maplogInk)

                    Spacer(minLength: 0)

                    Button("제거") {
                        clearAttachment()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.maplogMuted)
                    .buttonStyle(MaplogPressFeedbackStyle())
                }
            }

            HStack(spacing: MaplogSpacing.xSmall) {
                Image("home_profile_avatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                HStack(spacing: MaplogSpacing.xxSmall) {
                    TextField(
                        "",
                        text: $draft,
                        prompt: Text(replyTarget == nil ? "댓글을 입력하세요" : "답글을 입력하세요")
                            .foregroundStyle(Color.maplogMuted)
                    )
                        .font(.body)
                        .foregroundStyle(Color.maplogInk)
                        .tint(Color.maplogOlive)
                        .focused($isComposerFocused)
                        .submitLabel(.send)
                        .onSubmit(sendComment)
                        .accessibilityLabel(replyTarget == nil ? "새 댓글" : "새 답글")

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: "photo")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Color.maplogInk)
                            .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                    }
                    .buttonStyle(MaplogPressFeedbackStyle())
                    .accessibilityLabel("댓글 사진 추가")
                }
                .padding(.leading, MaplogSpacing.small)
                .padding(.trailing, MaplogSpacing.xxSmall)
                .frame(maxWidth: .infinity, minHeight: MaplogSize.controlHeight)
                .background(Color.maplogCanvas, in: Capsule())

                if canSend {
                    Button(action: sendComment) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.maplogOnPrimary)
                            .frame(width: MaplogSize.controlHeight, height: MaplogSize.controlHeight)
                            .background(Color.maplogPrimary, in: Circle())
                    }
                    .buttonStyle(MaplogPressFeedbackStyle())
                    .accessibilityLabel(replyTarget == nil ? "댓글 등록" : "답글 등록")
                }
            }
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, MaplogSpacing.small)
        .padding(.bottom, MaplogSpacing.small)
        .background(Color.maplogSurface)
    }

    private func replies(for comment: VlogComment) -> [VlogComment] {
        seededReplies[comment.id, default: []] + localReplies[comment.id, default: []]
    }

    private func baseLikeCount(for comment: VlogComment) -> Int {
        if comment.isMine { return 0 }
        if comment.id.contains("default-1") { return 12 }
        if comment.id.contains("default-2") { return 7 }
        if comment.id.contains("default-3") { return 4 }
        return 2
    }

    private func toggleReplies(for commentID: String, expanded: Bool) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            if expanded {
                expandedReplyIDs.remove(commentID)
            } else {
                expandedReplyIDs.insert(commentID)
            }
        }
    }

    private func startReply(to comment: VlogComment) {
        replyTarget = comment
        DispatchQueue.main.async {
            isComposerFocused = true
        }
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            await MainActor.run {
                attachmentData = data
            }
        }
    }

    private func clearAttachment() {
        attachmentData = nil
        selectedPhotoItem = nil
    }

    private func sendComment() {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty || attachmentData != nil else { return }

        if let replyTarget {
            let reply = VlogComment(
                id: "reply-\(UUID().uuidString)",
                author: sessionStore.profile.displayName,
                body: trimmedDraft,
                timeText: "방금",
                isMine: true,
                attachmentData: attachmentData
            )
            localReplies[replyTarget.id, default: []].append(reply)
            expandedReplyIDs.insert(replyTarget.id)
            self.replyTarget = nil
        } else {
            guard sessionStore.addVlogComment(
                postID: post.id,
                body: trimmedDraft,
                attachmentData: attachmentData
            ) != nil else {
                return
            }
        }

        draft = ""
        clearAttachment()
    }
}

private struct VlogCommentAttachmentImage: View {
    let data: Data

    var body: some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.maplogCanvas
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
        .accessibilityLabel("첨부한 사진")
    }
}
