//
//  Untitled.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//
//날짜 문자열이 잘못 내려오면 이는 네트워크 오류가 아니라 서버 데이터 계약 문제

enum FestivalRepositoryError: Error {
    case invalidDate(field: String, value: String)
}
