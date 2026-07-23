//
//  TourismAPIService.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//
//URL이나 URLSession 코드가 없습니다. “DTO 페이지를 가져올 수 있다”는 약속만 있음

protocol TourismAPIService {
    func fetchTourisms(
        category: TourismCategory,
        cursor: String?,
        size: Int
    ) async throws -> TourismPageDTO
}
