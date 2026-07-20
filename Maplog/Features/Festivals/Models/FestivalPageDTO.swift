//
//  FestivalPageDTO.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

import Foundation

struct Festival: Identifiable, Equatable {
    let id: String
    let name: String
    let region: String?
    let thumbnailURL: URL?
    let startDate: Date
    let endDate: Date
}
