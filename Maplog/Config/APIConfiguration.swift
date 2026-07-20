//
//  APIConfiguration.swift
//  Maplog
//
//  Created by 한채림 on 7/20/26.
//

import Foundation

enum APIConfiguration {
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
