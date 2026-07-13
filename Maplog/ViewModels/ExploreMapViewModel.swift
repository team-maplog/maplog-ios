import Foundation

final class ExploreMapViewModel: ObservableObject {
    @Published var selectedFilter = "전체"
    @Published var selectedSpot: MaplogSpot? = MockMaplogData.spots.first

    let filters = ["전체", "카페", "음식점", "행사", "축제"]
    let spots = MockMaplogData.spots

    var visibleSpots: [MaplogSpot] {
        guard selectedFilter != "전체" else { return spots }
        return spots.filter { $0.category == selectedFilter || $0.tags.contains(selectedFilter) }
    }

    func selectFilter(_ filter: String) {
        selectedFilter = filter
        selectedSpot = visibleSpots.first
    }

    func focusCurrentLocation() {
        selectedFilter = "전체"
        selectedSpot = MockMaplogData.forestCafe
    }
}
