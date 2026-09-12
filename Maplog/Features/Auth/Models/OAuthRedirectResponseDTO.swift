//
//  OAuthRedirectResponseDTO.swift
//  Maplog
//

import Foundation

struct OAuthRedirectResponseDTO: Decodable {
    let registrationID: String
    let redirectURL: String

    private enum CodingKeys: String, CodingKey {
        case registrationID = "registrationId"
        case redirectURL = "redirectUrl"
    }
}
