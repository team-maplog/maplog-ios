import AppIntents
import Foundation

struct QuickMaplogIntent: AppIntent {
    static var title: LocalizedStringResource = "빠른 Maplog 기록"
    static var description = IntentDescription("Maplog에서 빠른 여행 기록을 시작합니다.")
    static var openAppWhenRun = true

    @Parameter(title: "장소 이름")
    var placeName: String?

    func perform() async throws -> some IntentResult {
        let trimmedPlaceName = placeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        MaplogLaunchRequest.requestCapture(placeName: trimmedPlaceName)

        if let trimmedPlaceName, !trimmedPlaceName.isEmpty {
            return .result(dialog: "\(trimmedPlaceName) 촬영 화면을 열었어요.")
        }
        return .result(dialog: "Maplog 촬영 화면을 열었어요.")
    }
}

struct MaplogShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickMaplogIntent(),
            phrases: [
                "\(.applicationName)에서 빠른 기록",
                "\(.applicationName)으로 여행 기록"
            ],
            shortTitle: "빠른 기록",
            systemImageName: "camera.viewfinder"
        )
    }
}
