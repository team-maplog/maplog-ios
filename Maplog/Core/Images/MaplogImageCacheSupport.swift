//
//  MaplogImageCacheSupport.swift
//  Maplog
//
//  화면별 이미지 크기와 캐시 키 규칙을 한곳에서 관리합니다.
//

import CoreGraphics
import Foundation

/// 내려받은 원본을 이 픽셀 크기 이하로 줄인 뒤 캐시합니다.
/// 화면에서 필요한 크기보다 큰 원본을 그대로 메모리에 두지 않기 위한 값입니다.
struct MaplogImageTargetSize: Hashable {
    let width: CGFloat
    let height: CGFloat

    var size: CGSize {
        CGSize(width: width, height: height)
    }

    /// 64pt 아바타를 3배율 화면에서도 선명하게 보여 줄 수 있는 크기입니다.
    static let profileAvatar = Self(width: 192, height: 192)
    /// 검색·프로필 목록에 쓰는 로그 카드용 크기입니다.
    static let listThumbnail = Self(width: 640, height: 640)
    /// 홈 릴스처럼 세로 전체 화면에 쓰는 로그 대표 이미지용 크기입니다.
    static let reelCover = Self(width: 1_170, height: 2_532)
    /// 지도 라벨 안의 작은 사진용 크기입니다.
    static let mapMarker = Self(width: 144, height: 144)
}

/// URL의 서명·만료 시각처럼 매 요청마다 달라질 수 있는 query를 캐시 키에서 제외합니다.
/// 실제 요청은 원래 URL로 보내므로, 이 값은 "같은 이미지인가"를 판단하는 데만 사용됩니다.
enum MaplogImageCacheKey {
    private static let volatileQueryNames: Set<String> = [
        "access_token",
        "expires",
        "expiration",
        "signature",
        "sig",
        "timestamp",
        "token",
        "ts",
        "x-amz-credential",
        "x-amz-date",
        "x-amz-expires",
        "x-amz-security-token",
        "x-amz-signature"
    ]

    static func stableURL(_ url: URL) -> String {
        guard var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else {
            return "image-url:\(url.absoluteString)"
        }

        components.fragment = nil
        components.queryItems = components.queryItems?
            .filter { !volatileQueryNames.contains($0.name.lowercased()) }
            .sorted {
                if $0.name == $1.name {
                    return ($0.value ?? "") < ($1.value ?? "")
                }

                return $0.name < $1.name
            }

        return "image-url:\(components.url?.absoluteString ?? url.absoluteString)"
    }
}

/// Maplog API의 보호 이미지만 Authorization 헤더를 붙이도록 URL 범위를 제한합니다.
enum MaplogImageURLPolicy {
    static func requiresAuthentication(for url: URL) -> Bool {
        let baseURL = APIConfiguration.baseURL

        return url.scheme == baseURL.scheme
            && url.host == baseURL.host
            && url.port == baseURL.port
    }
}
