import Foundation

/// 세션 확인용 보호 API만 담당하는 Service임
protocol SessionValidationAPIService {
    func validateCurrentSession() async throws -> SessionValidationResponseDTO
}
