//
//  BackendErrorCode.swift
//  Maplog
//
//  Created by 한채림 on 7/23/26.
//서버의 문자열 코드를 앱이 이해할 수 있는 타입으로 번역

enum BackendErrorCode: Equatable {
    case tourAPIUnavailable
    case tourAPIRequestFailed
    case commonValidationFailure
    case duplicateReport
    case cannotReportOwnContent
    case cannotBlockSelf

    case expiredAccessToken
    case invalidAuthentication

    case unknown(String)

    case userNotFound
    case inactiveUser
    case suspendedUser
    case pendingUser
    case wrongPassword
    case cursorInvalid

    case commonNotFound
    case commonInvalidRequest
    case tourismNotFound

    case oauthConnectionNotFound
    case oauthRevokeFailed
    case oauthPrimaryConnectionRequired
    case oauthEmailPermissionRequired
    case oauthStateExpired
    case oauthEmailAlreadyInUse
    case oauthHandoffInvalid
    case oauthHandoffStoreUnavailable
    case requestRateLimited

    case fileTooLarge
    case unsupportedFileType
    case missingLogVideo
    case invalidLogVideo
    case logVideoAccessDenied
    case logVideoTooLong
    case logVideoResolutionTooLarge
    case thumbnailGenerationFailed
    case logVideoInspectionFailed
    case invalidThumbnailTime
    case invalidClipTimeRange
    case logPublishInProgress
    case invalidLogPublishIdempotencyKey
    case locationAddressNotFound
    case locationLookupFailed

    case logNotFound
    case logNotReadable
    case logNotOwner

    init(serverCode: String) {
        switch serverCode {
        case "REPORT-002": self = .duplicateReport
        case "REPORT-003": self = .cannotReportOwnContent
        case "BLOCK-001": self = .cannotBlockSelf
        case "TOUR-001":
            self = .tourAPIUnavailable

        case "TOUR-002":
            self = .tourAPIRequestFailed

        case "COMMON-014":
            self = .commonValidationFailure

        case "EXPIRED_TOKEN":
            self = .expiredAccessToken

        case "WRONG_TOKEN",
            "MALFORMED_JWT",
            "UNSUPPORTED_JWT",
            "ILLEGAL_ARGUMENT_JWT",
            "REFRESH_INVALID":
            self = .invalidAuthentication

        case "USER-001":
            self = .userNotFound

        case "USER-002":
            self = .inactiveUser

        case "USER-003":
            self = .suspendedUser

        case "USER-004":
            self = .pendingUser

        case "USER-006":
            self = .wrongPassword

        case "CURSOR-001":
            self = .cursorInvalid

        case "COMMON-003":
            self = .commonNotFound

        case "COMMON-001":
            self = .commonInvalidRequest

        case "TOUR-003":
            self = .tourismNotFound

        case "OAUTH-003", "OAUTH-009":
            self = .oauthEmailPermissionRequired

        case "OAUTH-004":
            self = .oauthStateExpired

        case "OAUTH-010":
            self = .oauthEmailAlreadyInUse

        case "OAUTH-005":
            self = .oauthConnectionNotFound
        case "OAUTH-007":
            self = .oauthRevokeFailed
        case "OAUTH-008":
            self = .oauthPrimaryConnectionRequired

        case "OAUTH-014":
            self = .oauthHandoffInvalid

        case "OAUTH-015":
            self = .oauthHandoffStoreUnavailable

        case "RATE-001":
            self = .requestRateLimited

        case "FILE-002":
            self = .fileTooLarge

        case "FILE-003":
            self = .unsupportedFileType

        case "LOG-004":
            self = .missingLogVideo

        case "LOG-005":
            self = .logVideoAccessDenied

        case "LOG-006":
            self = .invalidLogVideo

        case "LOG-007":
            self = .logVideoTooLong

        case "LOG-008":
            self = .logVideoResolutionTooLarge

        case "LOG-009":
            self = .thumbnailGenerationFailed

        case "LOG-011":
            self = .logVideoInspectionFailed

        case "LOG-010":
            self = .invalidThumbnailTime

        case "LOG-012":
            self = .invalidClipTimeRange

        case "LOG-013":
            self = .logPublishInProgress

        case "LOG-014":
            self = .invalidLogPublishIdempotencyKey

        case "LOCATION-002":
            self = .locationAddressNotFound

        case "LOCATION-003":
            self = .locationLookupFailed

        case "LOG-001":
            self = .logNotFound

        case "LOG-002":
            self = .logNotReadable

        case "LOG-003":
            self = .logNotOwner

        default:
            self = .unknown(serverCode)
        }
    }
}
//Equatable
//두 값이 같은지 비교할 수 있게 해줌
//다음 단계에서 정책 테스트를 쓸 때 도움이 됨, unknown(String) 안의 String도 비교 가능하므로 Swift가 자동으로 구현

//ase unknown(String)
//서버가 앱 업데이트보다 먼저 TOUR-003을 추가해도 앱이 죽지 않게 함
//예: .unknown("TOUR-003")
//나중에 이 경우는 일반 오류 화면을 보여주고, 개발 로그에는 원본 코드를 남기게 됨
