//
//  ClipEditorErrorPolicy.swift
//  Maplog
//
//  Created by 한채림 on 8/3/26.
//

import Foundation

enum ClipEditorErrorPolicy {
    static func playbackPresentation(
        for error: Error
    ) -> ErrorPresentation {
        if let playbackError = error as? VideoPlaybackServiceError {
            switch playbackError {
            case .noSourceVideos:
                return ErrorPresentation(
                    message: "편집할 영상을 찾지 못했어요.",
                    recoveryAction: .none
                )

            case .sourceVideoUnavailable:
                return ErrorPresentation(
                    message: "일부 클립을 불러올 수 없어요. 다시 촬영해 주세요.",
                    recoveryAction: .none
                )

            case .unableToCreateCompositionTrack:
                return ErrorPresentation(
                    message: "영상 미리보기를 준비하지 못했어요.",
                    recoveryAction: .retry
                )
            }
        }

        return ErrorPresentation(
            message: "영상 미리보기를 준비하지 못했어요. 잠시 후 다시 시도해 주세요.",
            recoveryAction: .retry
        )
    }
    
    static func exportPresentation(
        for error: Error
    ) -> ErrorPresentation {
        if let exportError = error as? VideoExportServiceError {
            switch exportError {
            case .noSourceVideos:
                return ErrorPresentation(
                    message: "내보낼 영상이 없어요.",
                    recoveryAction: .none
                )

            case .sourceVideoUnavailable:
                return ErrorPresentation(
                    message: "일부 클립 파일을 불러올 수 없어요. 다시 촬영해 주세요.",
                    recoveryAction: .none
                )

            case .unableToCreateCompositionTrack,
                 .unableToCreateExportSession:
                return ErrorPresentation(
                    message: "영상을 만들 준비를 하지 못했어요. 다시 시도해 주세요.",
                    recoveryAction: .retry
                )
            }
        }

        return ErrorPresentation(
            message: "영상을 만들지 못했어요. 잠시 후 다시 시도해 주세요.",
            recoveryAction: .retry
        )
    }
}
