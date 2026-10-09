//
//  APIConfiguration.swift
//  Maplog
//
//  Created by 한채림 on 7/20/26.
//

import Foundation

enum APIConfiguration {
    /// 인증 정보의 저장 영역은 서버 origin으로 구분하며 credential·query는 포함하지 않는다.
    static func storageNamespace(for baseURL: URL) -> String {
        guard let scheme = baseURL.scheme?.lowercased(),
              let host = baseURL.host?.lowercased(),
              scheme == "https" || scheme == "http" else {
            preconditionFailure("API 서버 주소를 확인해주세요.")
        }

        var origin = URLComponents()
        origin.scheme = scheme
        origin.host = host
        let defaultPort = scheme == "https" ? 443 : 80
        origin.port = baseURL.port == defaultPort ? nil : baseURL.port

        guard let url = origin.url else {
            preconditionFailure("API 서버 주소를 확인해주세요.")
        }
        return url.absoluteString
    }

    static let baseURL: URL = {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String else {
            fatalError("API_BASE_URL 설정을 확인해주세요.")
        }
        
        guard let url = URL(string: urlString) else {
            fatalError("API_BASE_URL 설정을 확인해주세요.")
        }
        
        return url
    }()
}
