import Foundation

/// 발행 옵션 화면이 토스트와 다음 화면 전환을 판단할 수 있도록 작업 결과를 담습니다.
struct LogPublicationCompletion: Equatable {
    let publishedLog: LogPublishResult?
    let savedToPhotoLibrary: Bool

    var message: String {
        switch (publishedLog != nil, savedToPhotoLibrary) {
        case (true, false):
            return "Maplog에 발행했어요."
        case (false, true):
            return "완성 영상을 기기에 저장했어요."
        case (true, true):
            return "Maplog에 발행하고 기기에도 저장했어요."
        case (false, false):
            return "완료한 작업이 없어요."
        }
    }
}
