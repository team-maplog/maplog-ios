import Foundation

@MainActor
final class NotificationProfileViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case content(FollowUser)
        case failed(ErrorPresentation)
    }

    @Published private(set) var state: State = .idle
    private let userID: UUID
    private let repository: any NotificationRepository

    init(userID: UUID, repository: any NotificationRepository) {
        self.userID = userID
        self.repository = repository
    }

    func load() async {
        guard state != .loading else { return }
        state = .loading
        do {
            // 푸시는 UUID만 주고 공개 프로필 API는 닉네임을 받으므로 서버 알림의 actor로 연결합니다.
            // 표시 문구를 파싱하거나 첫 페이지만 보고 사용자가 없다고 판단하지 않습니다.
            var cursor: String?
            var visitedCursors = Set<String>()
            repeat {
                let page = try await repository.fetchNotifications(cursor: cursor, size: 50)
                try Task.checkCancellation()
                if let actor = page.notifications.compactMap(\.actor).first(where: {
                    $0.id == userID && !($0.nickname?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                }), let nickname = actor.nickname {
                    state = .content(FollowUser(
                        id: userID,
                        nickname: nickname,
                        profileImageURL: actor.profileImageURL
                    ))
                    return
                }
                guard page.hasNext else { break }
                guard let next = page.nextCursor, !next.isEmpty,
                      visitedCursors.insert(next).inserted else {
                    throw APIError.invalidRequest(reason: "알림 페이지 커서가 올바르지 않습니다.")
                }
                cursor = next
            } while true
            state = .failed(ErrorPresentation(
                message: "이 알림의 사용자를 찾을 수 없어요. 알림 목록에서 다시 확인해 주세요.",
                recoveryAction: .none
            ))
        } catch is CancellationError {
            state = .idle
        } catch {
            guard !Task.isCancelled else { state = .idle; return }
            let presentation = NotificationErrorPolicy.presentation(for: error)
            state = .failed(ErrorPresentation(
                message: presentation.message,
                recoveryAction: presentation.recoveryAction == .signIn ? .signIn : .retry
            ))
        }
    }
}
