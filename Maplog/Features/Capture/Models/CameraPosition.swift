//
//  CameraPosition.swift
//  Maplog
//
//  Created by 한채림 on 7/31/26.
// Apple의 .back, .front 같은 AVFoundation 타입을 ViewModel까지 끌고 가지 않기 위한 앱 내부 모델

import Foundation

enum CameraPosition: Equatable, Sendable {
    case rear
    case front
}
