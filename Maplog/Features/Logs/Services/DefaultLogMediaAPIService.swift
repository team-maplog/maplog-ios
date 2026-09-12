//
//  DefaultLogMediaAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/14/26.
//

import Foundation

final class DefaultLogMediaAPIService: LogMediaAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient
    private let imageDataLoader: any ImageDataLoading

    init(
        authenticatedAPIClient: AuthenticatedAPIClient,
        imageDataLoader: any ImageDataLoading
    ) {
        self.authenticatedAPIClient = authenticatedAPIClient
        self.imageDataLoader = imageDataLoader
    }

    func fetchThumbnailData(
        logID: Int64,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data {
        let url = logMediaURL(logID: logID, resource: "thumbnail")

        return try await imageDataLoader.imageData(
            from: url,
            cacheKey: "log-thumbnail-\(logID)",
            targetSize: targetSize
        )
    }

    // 영상 요청 메서드
    func fetchPlaybackFileURL(logID: Int64) async throws -> URL {
        let url = logMediaURL(
            logID: logID,
            resource: "video"
        )

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("video/*", forHTTPHeaderField: "Accept")

        let temporaryURL = try await authenticatedAPIClient.download(
            for: request
        )

        return try persistPlaybackFile(
            from: temporaryURL,
            logID: logID
        )
    }

    func fetchRoutePointThumbnailData(
        from url: URL,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data {
        try await imageDataLoader.imageData(
            from: url,
            cacheKey: MaplogImageCacheKey.stableURL(url),
            targetSize: targetSize
        )
    }

    private func logMediaURL(
        logID: Int64,
        resource: String
    ) -> URL {
        APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("logs")
            .appendingPathComponent(String(logID))
            .appendingPathComponent(resource)
    }

    // 서버에서 받은 영상 파일을 앱이 재생할 수 있는 캐시 파일로 옮김
//    서버 영상 다운로드
//    → URLSession 임시 파일
//    → Caches/LogPlayback 폴더
//    → log-2.video 같은 로컬 파일
//    → AVPlayer 재생
    private func persistPlaybackFile(
        from temporaryURL: URL,
        logID: Int64
    ) throws -> URL {
        let fileManager = FileManager.default // 파일·폴더 생성, 이동, 삭제를 담당하는 iOS 기본 도구를 가져옴

        let cachesDirectory = try fileManager.url( // 앱의 Caches 폴더 위치를 찾음. 다시 서버에서 받을 수 있는 파일을 두는 공간. 저장 공간이 부족하면 iOS가 지울 수도 있으므로, 중요한 원본 영상을 영구 보관하는 위치는 아님
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let playbackDirectory = cachesDirectory // Caches 안에 Maplog 영상 전용 폴더를 만들 경로 Cache/logPlayback/log-2.video
            .appendingPathComponent(
                "LogPlayback",
                isDirectory: true
            )

        try fileManager.createDirectory( // LogPlayback 폴더가 없으면 생성 try가 붙은 건 저장 공간 부족 같은 파일 시스템 오류가 날 수 있기 때문
            at: playbackDirectory,
            withIntermediateDirectories: true
        )

        let playbackFileURL = playbackDirectory // 로그 ID를 파일명에 넣고, 어떤 로그 영상인지 구분. 예를 들어 logID == 2라면 log-2.mov가 됨
            .appendingPathComponent("log-\(logID).mov")

        if fileManager.fileExists( // 이미 같은 로그의 이전 영상 파일이 있다면 지움 moveItem은 같은 위치에 파일이 있으면 덮어쓰지 않고 실패하므로, 새 파일을 넣기 전에 정리
            atPath: playbackFileURL.path
        ) {
            try fileManager.removeItem(at: playbackFileURL)
        }

        try fileManager.moveItem( // 복사하지 않고 이동하므로, 임시 파일을 그대로 재생용 위치로 옮김. 불필요하게 영상 파일이 두 개 생기지 않음
            at: temporaryURL,
            to: playbackFileURL
        )

        return playbackFileURL
    }
}
