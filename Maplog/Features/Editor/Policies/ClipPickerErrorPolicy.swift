//
//  ClipPickerErrorPolicy.swift
//  Maplog
//
//  Created by 한채림 on 8/1/26.
//

import Foundation

enum ClipPickerErrorPolicy {
    static func presentation(for error: Error) -> ErrorPresentation {
        ErrorPresentation(
            message: "저장한 클립을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
            recoveryAction: .retry
        )
    }
    
    static func deletionPresentation(for error: Error) -> ErrorPresentation {
        ErrorPresentation(
            message: "클립을 삭제하지 못했어요. 다시 시도해 주세요.",
            recoveryAction: .none
        )
    }
}
