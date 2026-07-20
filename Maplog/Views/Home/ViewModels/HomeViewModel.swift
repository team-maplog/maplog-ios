import Foundation

final class HomeViewModel: ObservableObject {
    @Published var searchText = ""
    let trips = MockMaplogData.trips
    let recommendedSpots = MockMaplogData.spots
    let recentLogs = MockMaplogData.logs
}
