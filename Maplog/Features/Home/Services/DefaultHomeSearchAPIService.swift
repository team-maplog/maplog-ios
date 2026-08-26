import Foundation

final class DefaultHomeSearchAPIService: HomeSearchAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(authenticatedAPIClient: AuthenticatedAPIClient) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func search(
        request: HomeSearchRequest
    ) async throws -> HomeSearchPageDTO {
        let query = request.query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard (1...50).contains(query.count) else {
            throw APIError.invalidRequest(
                reason: "검색어는 공백을 제외하고 1자 이상 50자 이하여야 합니다."
            )
        }

        guard (1...50).contains(request.size) else {
            throw APIError.invalidRequest(
                reason: "검색 결과 개수는 1부터 50 사이여야 합니다."
            )
        }

        let endpoint = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("search")

        var components = URLComponents(
            url: endpoint,
            resolvingAgainstBaseURL: false
        )

        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "scope", value: request.scope.rawValue),
            URLQueryItem(name: "size", value: String(request.size)),
            URLQueryItem(name: "sort", value: request.sort.rawValue)
        ]

        // cursor는 서버 내부 형식을 담은 opaque 값입니다. 앱은 받은 값을 손대지 않고 그대로만 보냅니다.
        if let cursor = request.cursor {
            queryItems.append(
                URLQueryItem(name: "cursor", value: cursor)
            )
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let response: APIResponse<HomeSearchPageDTO> =
            try await authenticatedAPIClient.request(
                urlRequest,
                responseType: APIResponse<HomeSearchPageDTO>.self
            )

        guard response.successFlag,
              response.code == "SUCCESS-002"
        else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }

        guard let data = response.data else {
            throw APIError.missingData
        }

        return data
    }
}
