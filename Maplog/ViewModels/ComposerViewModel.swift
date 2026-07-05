import Foundation

final class ComposerViewModel: ObservableObject {
    @Published var selectedSpot: MaplogSpot?
    @Published var selectedMood = "좋았어요"
    @Published var rating = 4
    @Published var note = "오늘의 장소에서 기억하고 싶은 순간을 적어보세요."

    let moods = ["좋았어요", "편안해요", "또 갈래요", "새로워요"]

    init(initialSpot: MaplogSpot? = nil) {
        selectedSpot = initialSpot ?? MockMaplogData.spots.first
    }

    var draft: ComposerDraft {
        ComposerDraft(
            placeName: selectedSpot?.name ?? "장소 선택",
            mood: selectedMood,
            rating: rating,
            note: note,
            imageStyle: selectedSpot?.imageStyle ?? .city
        )
    }
}
