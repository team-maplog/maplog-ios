import Foundation

final class DefaultNotificationAPIService: NotificationAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(authenticatedAPIClient: AuthenticatedAPIClient) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func registerFCMToken(
        _ registration: FCMTokenRegistration
    ) async throws {
        let endpoint = notificationEndpoint.appendingPathComponent("fcm-token")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            FCMTokenRegistrationRequestDTO(registration: registration)
        )

        let response: APIResponse<EmptyNotificationResponseDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<EmptyNotificationResponseDTO>.self
            )

        guard response.successFlag, response.code == "SUCCESS-001" else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }
    }

    func unregisterFCMToken(deviceID: String) async throws {
        var components = URLComponents(
            url: notificationEndpoint.appendingPathComponent("fcm-token"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "deviceId", value: deviceID)
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: APIResponse<EmptyNotificationResponseDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<EmptyNotificationResponseDTO>.self
            )

        guard response.successFlag, response.code == "SUCCESS-004" else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }
    }

    func fetchNotifications(
        cursor: String?,
        size: Int
    ) async throws -> NotificationPageDTO {
        guard (1...50).contains(size) else {
            throw APIError.invalidRequest(
                reason: "알림 조회 개수는 1부터 50 사이여야 합니다."
            )
        }

        var components = URLComponents(
            url: notificationEndpoint,
            resolvingAgainstBaseURL: false
        )
        var queryItems = [URLQueryItem(name: "size", value: String(size))]
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: APIResponse<NotificationPageDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<NotificationPageDTO>.self
            )

        guard response.successFlag, response.code == "SUCCESS-002" else {
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

    private var notificationEndpoint: URL {
        APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("notifications")
    }
}

private struct FCMTokenRegistrationRequestDTO: Encodable {
    let deviceID: String
    let fcmToken: String

    init(registration: FCMTokenRegistration) {
        deviceID = registration.deviceID
        fcmToken = registration.fcmToken
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "deviceId"
        case fcmToken
    }
}

private struct EmptyNotificationResponseDTO: Decodable {}
