//
//  APIClienttled.swift
//  Maplog
//
//  Created by 한채림 on 7/18/26.
//

import Foundation

enum APIError: Error {
    case invalidResponse
    case server(statusCode: Int, response: APIErrorResponse)
    case network(Error)
    case decoding(Error)
}
