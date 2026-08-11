//
//  CaptureLocation.swift
//  Maplog
//
//  Created by 한채림 on 7/30/26.
// 촬영 위치 모델

import Foundation

struct CaptureLocation: Equatable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    let placeName: String?
}
