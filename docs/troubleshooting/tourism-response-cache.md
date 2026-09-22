# 관광 데이터 반복 조회 줄이기

## 문제

- 관광 목록의 간헐적인 `502 / TOUR-002` 조사 중 목록·상세 조회가 반복되는 흐름 확인.
- 홈 포스터의 이미지 주소 조회와 상세 화면 진입이 같은 상세 API 사용. 이미지 파일 캐시만으로 메타데이터 요청까지 줄일 수 없는 구조.
- 외부 API 실패의 직접 원인은 미확정. 앱에서 확인한 반복 조회와 오류 시 화면 처리를 개선 범위로 설정.

## 판단과 선택

| 선택 | 이유 | 감수한 제약 |
| --- | --- | --- |
| 공통 Repository에서 Domain Model 캐싱 | 홈·목록·상세가 응답을 공유하고 DTO 변환에 성공한 값만 재사용 | 앱 종료 후 캐시 소멸 |
| 유효기간 600초 | 자동 재조회 횟수와 정보 최신성 사이의 초기 정책 | 운영 측정으로 정한 최적값은 아님 |
| 키별 진행 중 Task 공유 | 첫 응답이 오기 전 겹치는 요청까지 줄이기 | 개별 호출자 취소 시 공용 요청의 즉시 중단은 하지 않음 |
| 사용자 새로고침은 `.reload` | 유효기간 안에도 최신 정보를 요청할 경로 확보 | 이미 진행 중인 동일 요청은 공유 |
| 갱신 실패 시 기존 목록 유지 | 새 정보를 못 받았다는 이유로 읽던 정보까지 사라지는 상황 방지 | 오래된 목록과 갱신 오류를 함께 표시 |

목록 키는 `category + cursor + size`, 상세 키는 `tourismID`. 화면이 달라도 같은 조건이면 재사용하고 다른 페이지·카테고리는 분리.

## 처리 흐름

```text
홈·목록·상세 View
  → ViewModel: 일반 조회 / 사용자 새로고침 구분
  → TourismRepository: 캐시 확인 → 진행 중 요청 공유
  → TourismAPIService → APIClient
  → DTO 변환 성공 → Domain Model 저장 → 화면 상태 반영
```

- `actor`로 캐시 상태 접근 관리. `await` 중 다른 요청이 들어올 수 있어 요청 ID·무효화 세대도 확인.
- 캐시 무효화 이후 늦게 도착한 응답은 저장·반환 차단.
- 실패 응답·DTO 변환 실패는 저장하지 않음. 실패한 새로고침은 기존 캐시의 유효기간도 연장하지 않음.
- 한국 날짜가 바뀌면 다음 접근에서 캐시 무효화. 세션 변경·메모리 경고에도 캐시 비우기 연결.
- 목록 응답 20개·상세 응답 100개로 상한 설정. 초과 시 저장 시각이 가장 오래된 항목 제거.
- 첫 페이지 새로고침 시 관련 페이지 캐시 제거. `CURSOR-001` 복구도 첫 페이지를 강제로 재조회해 오래된 커서 재사용 방지.

## 검증

2026-09-22 iOS Simulator 재실행 기준, 아래 두 테스트 클래스의 **17개 테스트 통과**. 실제 서버 대신 호출 횟수를 기록하는 로더·API Stub과 조절 가능한 시계 사용.

| 조건 | 확인 결과 |
| --- | --- |
| 같은 키 순차 요청 10회 | 로더 실행 1회 |
| 같은 키 동시 요청 10개 | 공용 로더 실행 1회 |
| 저장 후 599초 / 600초 | 캐시 재사용 / 재조회 |
| 한국 자정 경과 | 유효기간 안의 캐시도 무효화 |
| 무효화 후 이전 요청 완료 | 새 캐시를 덮어쓰지 않음 |
| 대기 중인 호출자 하나 취소 | 다른 호출자는 공용 결과 수신 |
| 새로고침 실패 | 기존 목록 유지, 오류·재시도 안내 |
| 잘못된 커서 | 캐시를 우회한 첫 페이지 재조회 |

운영 요청 수·응답 지연·장애율 개선은 미측정. 첫 요청·만료 후 요청에서는 외부 API 오류가 여전히 발생할 수 있음.

## 관련 코드

- [TourismResponseCache](../../Maplog/Features/Tourisms/Repositories/TourismResponseCache.swift) — 만료·동시 요청 공유·무효화
- [DefaultTourismRepository](../../Maplog/Features/Tourisms/Repositories/DefaultTourismRepository.swift) — 캐시 키·DTO 변환·페이지 정책
- [TourismListViewModel](../../Maplog/Features/Tourisms/ViewModels/TourismListViewModel.swift) — 기존 목록 유지·재시도 상태
- [TourismResponseCacheTests](../../MaplogTests/TourismResponseCacheTests.swift) — 캐시 경계 조건 8개
- [TourismRepositoryCacheTests](../../MaplogTests/TourismRepositoryCacheTests.swift) — Repository·화면 상태 연계 9개

## 정리

이미지 캐시와 응답 캐시의 역할을 구분하고 여러 화면이 공유하는 데이터의 수명을 Repository에서 관리. 캐시 적중뿐 아니라 만료·갱신·취소 이후의 결과 반영까지 검증 범위에 포함.
