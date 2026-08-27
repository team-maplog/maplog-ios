//
//  LogPublicationDestination.swift
//  Maplog
//

import Foundation

enum LogPublicationDestination: Hashable, CaseIterable, Identifiable {
    case maplog
    case photoLibrary

    var id: Self { self }

    var title: String {
        switch self {
        case .maplog:
            return "Maplog에 발행"
        case .photoLibrary:
            return "사진 앱에 저장"
        }
    }

    var detail: String {
        switch self {
        case .maplog:
            return "프로필과 릴스에서 다른 사용자에게 보여요"
        case .photoLibrary:
            return "내 사진 앱에 완성 영상을 보관해요"
        }
    }

    var systemImage: String {
        switch self {
        case .maplog:
            return "paperplane.fill"
        case .photoLibrary:
            return "square.and.arrow.down"
        }
    }
}

struct LogPublicationCompletion: Equatable {
    let publishedLog: LogPublishResult?
    let savedToPhotoLibrary: Bool

    var message: String {
        switch (publishedLog != nil, savedToPhotoLibrary) {
        case (true, true):
            return "Maplog에 발행하고 사진 앱에도 저장했어요."
        case (true, false):
            return "로그 발행이 완료됐어요."
        case (false, true):
            return "완성 영상을 사진 앱에 저장했어요."
        case (false, false):
            return "완료한 작업이 없어요."
        }
    }
}
