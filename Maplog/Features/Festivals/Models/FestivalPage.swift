//
//  FestivalPage.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

import Foundation

struct FestivalPage: Equatable {
    let festivals: [Festival]
    let hasNext: Bool
    let nextCursor: String?
}
