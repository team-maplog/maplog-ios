import SwiftUI

private struct ContentModerationRepositoryKey: EnvironmentKey {
    static let defaultValue: (any ContentModerationRepository)? = nil
}

extension EnvironmentValues {
    var contentModerationRepository: (any ContentModerationRepository)? {
        get { self[ContentModerationRepositoryKey.self] }
        set { self[ContentModerationRepositoryKey.self] = newValue }
    }
}

struct ContentModerationMenu: View {
    let logID: Int64?
    @Environment(\.maplogLogout) private var signIn
    @StateObject private var viewModel: ContentModerationViewModel
    @State private var showsReport = false
    @State private var showsBlock = false
    @State private var reason = ""

    init(logID: Int64? = nil, authorID: UUID, repository: any ContentModerationRepository,
         profileRepository: any ProfileRepository) {
        self.logID = logID
        _viewModel = StateObject(wrappedValue: ContentModerationViewModel(
            repository: repository, profileRepository: profileRepository, authorID: authorID
        ))
    }

    var body: some View {
        Group {
            if !viewModel.hasLoadedViewer || viewModel.canModerate {
                moderationMenu
            }
        }
        .task { await viewModel.prepare() }
        .alert("게시물 신고", isPresented: $showsReport) {
            TextField("신고 사유 (최대 1,000자)", text: $reason)
            Button("취소", role: .cancel) {}
            Button("신고", role: .destructive) {
                if let logID { Task { await viewModel.report(logID: logID, reason: reason) } }
            }
            .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reason.utf16.count > 1000)
        } message: { Text("이 게시물을 신고하는 이유를 알려주세요.") }
        .confirmationDialog("사용자를 차단할까요?", isPresented: $showsBlock, titleVisibility: .visible) {
            Button("사용자 차단", role: .destructive) { Task { await viewModel.block() } }
        } message: { Text("서로의 게시물과 댓글이 숨겨지며 열려 있는 화면을 닫고 홈을 다시 불러옵니다.") }
        .alert("신고 접수", isPresented: Binding(get: { viewModel.message != nil }, set: { if !$0 { viewModel.message = nil } })) {
            Button("확인", role: .cancel) { viewModel.message = nil }
        } message: { Text(viewModel.message ?? "") }
        .alert("요청을 완료하지 못했어요", isPresented: Binding(get: { viewModel.error != nil }, set: { if !$0 { viewModel.dismissError() } })) {
            if viewModel.error?.recoveryAction == .signIn { Button("다시 로그인", action: signIn) }
            Button("확인", role: .cancel) { viewModel.dismissError() }
        } message: { Text(viewModel.error?.message ?? "") }
    }

    private var moderationMenu: some View {
        Menu {
            if viewModel.canModerate {
                if logID != nil {
                    Button("게시물 신고", systemImage: "flag") { reason = ""; showsReport = true }
                }
                Button("사용자 차단", systemImage: "person.crop.circle.badge.xmark", role: .destructive) {
                    showsBlock = true
                }
            } else {
                Button("계정 확인 다시 시도") { Task { await viewModel.prepare() } }
            }
        } label: {
            if viewModel.isBusy {
                ProgressView().frame(width: 44, height: 44)
            } else {
                Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle())
            }
        }
        .foregroundStyle(Color.maplogInk)
        .disabled(viewModel.isBusy)
        .accessibilityLabel(logID == nil ? "사용자 차단 메뉴" : "게시물 신고 및 사용자 차단 메뉴")
    }

}
