import Foundation

@MainActor
final class ContentModerationViewModel: ObservableObject {
    @Published private(set) var isBusy = false
    @Published private(set) var canModerate = false
    @Published private(set) var hasLoadedViewer = false
    @Published var message: String?
    @Published private(set) var error: ErrorPresentation?
    private let repository: any ContentModerationRepository
    private let profileRepository: any ProfileRepository
    private let authorID: UUID

    init(repository: any ContentModerationRepository, profileRepository: any ProfileRepository, authorID: UUID) {
        self.repository = repository
        self.profileRepository = profileRepository
        self.authorID = authorID
    }

    func prepare() async {
        do {
            let viewer = try await profileRepository.fetchMyProfile()
            guard !Task.isCancelled else { return }
            canModerate = viewer.id != authorID
            hasLoadedViewer = true
            error = nil
        } catch {
            self.error = LogCommentErrorPolicy.actionPresentation(for: error, actionName: "계정을 확인")
        }
    }

    func report(logID: Int64, reason: String) async {
        guard canModerate, !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            try await repository.reportLog(id: logID, reason: reason)
            message = "신고가 접수됐어요. 검토 후 필요한 조치를 진행합니다."
        } catch {
            self.error = LogCommentErrorPolicy.actionPresentation(for: error, actionName: "게시물을 신고")
        }
    }

    func block() async {
        guard canModerate, !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            try await repository.blockUser(id: authorID)
            // 기존 댓글 차단과 같은 경로로 열려 있는 화면과 미디어 캐시를 갱신한다.
            NotificationCenter.default.post(name: .maplogUserBlockDidChange, object: nil)
        } catch {
            self.error = LogCommentErrorPolicy.actionPresentation(for: error, actionName: "사용자를 차단")
        }
    }

    func dismissError() { error = nil }
}
