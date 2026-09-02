//
//  LogPublishErrorPolicy.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// 발행 전용 오류 정책

import Foundation

enum LogPublishErrorPolicy {
    static func presentation(
        for error: Error
    ) -> ErrorPresentation {
        guard let apiError = error as? APIError else {
            return defaultPresentation
        }

        switch apiError {
        // HTTP 성공 응답을 끝까지 해석하지 못한 경우에는 서버가 이미 로그를 만들었을 수 있습니다.
        // 같은 Idempotency-Key로 재시도해 중복 발행 여부를 서버에 맡깁니다.
        case .network,
             .invalidResponse,
             .decoding,
             .missingData:
            return retryPresentation

        case .missingAccessToken:
            return authenticationPresentation

        case .invalidRequest:
            return ErrorPresentation(
                message: "완성된 영상 파일을 찾을 수 없어요. 다시 영상을 만들어 주세요.",
                recoveryAction: .none
            )

        case .server(let statusCode, let response):
            if let captionError = response.data?.first(
                where: { $0.field == "caption" }
            ) {
                return ErrorPresentation(
                    message: captionError.message,
                    recoveryAction: .none
                )
            }

            let errorCode = BackendErrorCode(
                serverCode: response.code
            )

            return serverPresentation(
                for: errorCode,
                statusCode: statusCode
            )

        default:
            return defaultPresentation
        }
    }

    private static func serverPresentation(
        for errorCode: BackendErrorCode,
        statusCode: Int
    ) -> ErrorPresentation {
        switch errorCode {
        case .expiredAccessToken,
             .invalidAuthentication:
            return authenticationPresentation

        case .fileTooLarge:
            return ErrorPresentation(
                message: "영상 용량이 너무 커요. 250MB 이하 영상으로 다시 만들어 주세요.",
                recoveryAction: .none
            )

        case .unsupportedFileType:
            return ErrorPresentation(
                message: "지원하지 않는 영상 형식이에요. 다시 영상을 만들어 주세요.",
                recoveryAction: .none
            )

        case .missingLogVideo,
             .invalidLogVideo:
            return ErrorPresentation(
                message: "완성된 영상 파일을 확인할 수 없어요. 다시 영상을 만들어 주세요.",
                recoveryAction: .none
            )

        case .logVideoTooLong:
            return ErrorPresentation(
                message: "완성 영상은 3분 이하여야 해요.",
                recoveryAction: .none
            )

        case .logVideoResolutionTooLarge:
            return ErrorPresentation(
                message: "영상의 가로와 세로는 각각 1920px 이하여야 해요.",
                recoveryAction: .none
            )

        case .invalidThumbnailTime:
            return ErrorPresentation(
                message: "선택한 커버 시점을 확인해 주세요.",
                recoveryAction: .none
            )

        case .invalidClipTimeRange:
            return ErrorPresentation(
                message: "클립별 시간 범위를 확인해 주세요.",
                recoveryAction: .none
            )

        case .commonInvalidRequest:
            return ErrorPresentation(
                message: "클립 시간과 해시태그 입력을 확인해 주세요.",
                recoveryAction: .none
            )

        case .thumbnailGenerationFailed:
            return retryPresentation

        default:
            if (500...599).contains(statusCode) {
                return retryPresentation
            }

            return defaultPresentation
        }
    }

    private static let retryPresentation = ErrorPresentation(
        message: "로그를 발행하지 못했어요. 잠시 후 다시 시도해 주세요.",
        recoveryAction: .retry
    )

    private static let authenticationPresentation = ErrorPresentation(
        message: "로그인 정보가 만료되었어요. 다시 로그인해 주세요.",
        recoveryAction: .signIn
    )

    private static let defaultPresentation = ErrorPresentation(
        message: "로그를 발행하지 못했어요. 입력 내용을 확인해 주세요.",
        recoveryAction: .none
    )
}
