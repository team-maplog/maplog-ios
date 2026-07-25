//
//  TourismCategoryTabViewData.swift
//  Maplog
//
//  Created by 한채림 on 7/26/26.
//

struct TourismCategoryTabViewData: Identifiable {
    let category: TourismCategory
    let title: String

    var id: TourismCategory { category }
}
