//
//  BackendErrorCode.swift
//  Maplog
//
//  Created by 한채림 on 7/23/26.
//

enum BackendErrorCode: Equatable {
    case tourAPIUnavailable
    case tourAPIRequestFailed
    case commonValidationFailure
    
    case expiredAccessToken
    case invalidAuthentication
    
    case unknown(String)
    
    init(serverCode: String) {
        switch serverCode {
        case "TOUR-001":
            self = .tourAPIUnavailable
            
        case "TOUR-002":
            self = .tourAPIRequestFailed
            
        case "COMMON-014":
            self = .commonValidationFailure
            
        case "EXPIRED_TOKEN":
            self = .expiredAccessToken
            
        case "WRONG_TOKEN",
            "MALFORMED_JWT",
            "UNSUPPORTED_JWT",
            "ILLEGAL_ARGUMENT_JWT",
            "REFRESH_INVALID":
            self = .invalidAuthentication
            
        default:
            self = .unknown(serverCode)
        }
    }
}
