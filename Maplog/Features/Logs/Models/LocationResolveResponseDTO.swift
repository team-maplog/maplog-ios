//
//  LocationResolveResponseDTO.swift
//  Maplog
//
//  Created by 한채림 on 8/12/26.
// 서버 응답 전용

import Foundation

struct LocationResolveResponseDTO: Decodable {
    let name: String?
    let address: String
    let latitude: Double
    let longitude: Double
}
