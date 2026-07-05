import Foundation

final class ProfileViewModel: ObservableObject {
    @Published private(set) var logs = MockMaplogData.logs
    let collections = MockMaplogData.collections

    func stats(logCount: Int) -> [(String, String)] {
        [
            ("로그", "\(logCount)"),
            ("팔로워", "256"),
            ("팔로잉", "128")
        ]
    }

    func deleteLog(_ log: TravelLog) {
        logs.removeAll { $0.id == log.id }
    }
}
