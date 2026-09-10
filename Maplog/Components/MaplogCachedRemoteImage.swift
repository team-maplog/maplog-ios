//
//  MaplogCachedRemoteImage.swift
//  Maplog
//
//  관광지처럼 URL을 바로 가진 공개 이미지를 Kingfisher로 표시합니다.
//

import Kingfisher
import SwiftUI

/// SwiftUI의 AsyncImage 대신 사용하는 공통 원격 이미지 View입니다.
/// 실제 URL은 다운로드에만 쓰고, cacheKey는 변하지 않는 관광 ID 또는 정규화한 URL을 사용합니다.
struct MaplogCachedRemoteImage<Placeholder: View>: View {
    let url: URL
    let cacheKey: String
    let targetSize: CGSize
    let contentMode: SwiftUI.ContentMode
    let placeholder: () -> Placeholder
    let onFailure: (() -> Void)?

    @Environment(\.displayScale) private var displayScale
    @EnvironmentObject private var authSessionStore: AuthSessionStore
    @State private var didFail = false

    init(
        url: URL,
        cacheKey: String,
        targetSize: CGSize,
        contentMode: SwiftUI.ContentMode,
        onFailure: (() -> Void)? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.cacheKey = cacheKey
        self.targetSize = targetSize
        self.contentMode = contentMode
        self.placeholder = placeholder
        self.onFailure = onFailure
    }

    var body: some View {
        if didFail {
            placeholder()
        } else {
            KFImage(
                source: .network(
                    KF.ImageResource(
                        downloadURL: url,
                        cacheKey: cacheKey
                    )
                )
            )
            .targetCache(MaplogImageCache.shared)
            .setProcessor(
                DownsamplingImageProcessor(size: targetPixelSize)
            )
            .requestModifier(
                MaplogImageAuthorizationModifier(
                    accessTokenProvider: authSessionStore
                )
            )
            .onFailure { _ in
                didFail = true
                onFailure?()
            }
            .resizable()
            .aspectRatio(contentMode: contentMode)
        }
    }

    private var targetPixelSize: CGSize {
        CGSize(
            width: max(1, targetSize.width * displayScale),
            height: max(1, targetSize.height * displayScale)
        )
    }
}

/// Kingfisher가 직접 요청하는 경우에도 Maplog API 범위에서만 Bearer 토큰을 붙입니다.
/// 토큰 값은 캐시 키나 로그에 저장하지 않습니다.
private final class MaplogImageAuthorizationModifier:
    AsyncImageDownloadRequestModifier,
    @unchecked Sendable {
    private let accessTokenProvider: any AccessTokenProviding

    init(
        accessTokenProvider: any AccessTokenProviding
    ) {
        self.accessTokenProvider = accessTokenProvider
    }

    var onDownloadTaskStarted: (@Sendable (DownloadTask?) -> Void)? {
        nil
    }

    func modified(
        for request: URLRequest
    ) async -> URLRequest? {
        guard let url = request.url,
              MaplogImageURLPolicy.requiresAuthentication(for: url)
        else {
            return request
        }

        guard let accessToken = try? await accessTokenProvider.currentAccessToken(),
              !accessToken.isEmpty
        else {
            return nil
        }

        var authorizedRequest = request
        authorizedRequest.setValue(
            "Bearer \(accessToken)",
            forHTTPHeaderField: "Authorization"
        )
        return authorizedRequest
    }
}
