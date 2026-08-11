//
//  ResolvedLogLocation.swift
//  Maplog
//
//  Created by 한채림 on 8/12/26.
// 앱 안에서 쓸 도메인 모델
//LogLocationDraft
//= 사용자가 저장 전 편집하는 위치
//
//ResolvedLogLocation
//= 서버가 좌표를 주소로 해석한 결과
import Foundation

struct ResolvedLogLocation: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let name: String?
    let address: String
}
