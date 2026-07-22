//
//  Festival.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

// 서버 JSON 그대로가 아니라, 앱이 사용할 타입

import Foundation

struct Festival: Identifiable, Equatable {
    let id: Int64
    let name: String
    let region: String?
    let thumbnailURL: URL?
    let startDate: Date
    let endDate: Date
}
