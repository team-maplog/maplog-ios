//
//  KingfisherImageDataLoader.swift
//  Maplog
//
//  인증 이미지와 로그 썸네일을 Kingfisher의 메모리·디스크 캐시에 저장합니다.
//

import Foundation
import Kingfisher
import UIKit

@MainActor
protocol ImageDataLoading: AnyObject {
    func imageData(
        from url: URL,
        cacheKey: String,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data
}

/// Kingfisher가 관리하는 앱 공통 이미지 저장소입니다.
/// 메모리에는 화면에 다시 그릴 UIImage를, 디스크에는 다운샘플링된 파일을 둡니다.
enum MaplogImageCache {
    static let shared: ImageCache = {
        let cache = ImageCache(name: "com.maplog.images")
        cache.memoryStorage.config.totalCostLimit = 96 * 1_024 * 1_024
        cache.diskStorage.config.sizeLimit = 200 * 1_024 * 1_024
        cache.diskStorage.config.expiration = .days(14)
        return cache
    }()
}

@MainActor
final class KingfisherImageDataLoader: ImageDataLoading {
    private let apiClient: APIClient
    private let authenticatedAPIClient: AuthenticatedAPIClient
    private let imageCache: ImageCache
    private let manager: KingfisherManager

    init(
        apiClient: APIClient,
        authenticatedAPIClient: AuthenticatedAPIClient,
        imageCache: ImageCache = MaplogImageCache.shared
    ) {
        self.apiClient = apiClient
        self.authenticatedAPIClient = authenticatedAPIClient
        self.imageCache = imageCache
        self.manager = KingfisherManager(
            downloader: .default,
            cache: imageCache
        )
    }

    func imageData(
        from url: URL,
        cacheKey: String,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data {
        let processor = DownsamplingImageProcessor(size: targetSize.size)
        let options: KingfisherOptionsInfo = [
            .processor(processor),
            .waitForCache
        ]

        if let cachedImage = try? await imageCache
            .retrieveImage(
                forKey: cacheKey,
                options: options
            )
            .image {
            return try encodedImageData(from: cachedImage)
        }

        let originalData = try await downloadImageData(from: url)
        let provider = RawImageDataProvider(
            data: originalData,
            cacheKey: cacheKey
        )
        let result = try await manager.retrieveImage(
            with: .provider(provider),
            options: options
        )

        return try encodedImageData(from: result.image)
    }

    private func downloadImageData(
        from url: URL
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        if MaplogImageURLPolicy.requiresAuthentication(for: url) {
            // 보호 이미지는 기존 인증 클라이언트를 거칩니다.
            // 따라서 Authorization 헤더뿐 아니라 EXPIRED_TOKEN의 1회 갱신 정책도 유지됩니다.
            return try await authenticatedAPIClient.data(for: request)
        }

        return try await apiClient.data(for: request)
    }

    private func encodedImageData(
        from image: UIImage
    ) throws -> Data {
        if let data = image.kf.data(format: .unknown) {
            return data
        }

        throw ImageDataLoaderError.cannotEncodeProcessedImage
    }
}

private enum ImageDataLoaderError: Error {
    case cannotEncodeProcessedImage
}
