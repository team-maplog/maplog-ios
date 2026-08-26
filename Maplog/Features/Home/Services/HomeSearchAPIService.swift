import Foundation

protocol HomeSearchAPIService {
    func search(
        request: HomeSearchRequest
    ) async throws -> HomeSearchPageDTO
}
