# 지도에서 영상을 다시 열 때 멈추던 미리보기

## 문제와 원인

- 경로의 장소 카드에서 재생을 요청해도 멈춘 미리보기가 남는 현상.
- 다운로드 취소 시 로딩 표시만 사라지고 활성 영상 ID는 유지. 같은 영상을 다시 고르면 실제 재생 항목 없이 준비 완료 분기로 진입.
- 동일 영상을 닫고 다시 열면 영상 ID만으로 이전 요청과 새 요청을 구별할 수 없음. 늦게 끝난 다운로드·시점 이동 결과가 새 재생 상태에 영향을 줄 가능성.

## 판단과 선택

**같은 영상인지와 현재 요청인지를 별도로 확인.**

| 변경 | 이유 |
| --- | --- |
| 재사용 조건에 `player.currentItem != nil` 추가 | 활성 ID만 남은 상태를 재생 준비 완료로 판단하지 않기 |
| 다운로드·시점 이동에 각각 요청 ID 부여 | 같은 영상·같은 시점으로 돌아와도 오래된 완료 결과 구분 |
| 현재 다운로드 취소 시 재생 상태 함께 정리 | 같은 영상을 다시 선택하면 정상적으로 다운로드 재시작 |
| 최신 시점 이동 실패를 재시도 상태로 표시 | 멈춘 미리보기만 남는 상황에서 복구 경로 제공 |
| 중지·수동 탐색 시 이전 자동 이동 무효화 | 이전 완료 콜백이 사용자의 최신 행동을 덮어쓰지 않도록 처리 |

## 처리 흐름

```text
HomeMapRoutePlaceCard에서 장소 선택
  → HomeView가 재생 행동 전달
  → HomeViewModel: 다운로드 요청 ID·목표 시점 관리
  → LogMediaRepository: 재생 파일 준비
  → VideoPlaybackService: 영상 로딩·시점 이동·재생
  → 현재 요청의 결과만 화면 상태에 반영
```

서버 API 계약과 카드 UI를 바꾸지 않고 ViewModel의 비동기 상태 관리에서 해결. 다운로드와 시점 이동은 별도 작업이므로 각각 최신 요청 여부 확인.

## 검증

2026-09-22 iOS Simulator 재실행 기준, `HomeRoutePlaybackTests` **5개**와 `AVVideoPlaybackSeekTests` **3개 통과**.

| 조건 | 확인 결과 |
| --- | --- |
| 다운로드 취소 후 같은 영상 선택 | 재다운로드 후 선택한 시점으로 이동 |
| 최신 시점 이동 실패 | 재시도 가능한 실패 상태 |
| 중지·재요청 후 이전 시점 이동 완료 | 이전 콜백으로 재생 시작하지 않음 |
| 장소를 연속 선택 | 마지막 목표 시점 우선 |
| 이전 다운로드의 늦은 취소 | 새 요청의 재생 상태 유지 |

ViewModel 테스트는 Mock Repository·Service 사용. AVFoundation 테스트는 합성 로컬 영상으로 시점 이동 후 시간 진행, 독립 플레이어 간 중지 영향 분리, URL 영상 반복 재생 시 같은 재생 항목 유지를 확인.

사용자 기기의 실제 영상·지도 SDK·네트워크 중단 조합은 미검증. 실기기에서는 다운로드 중 화면 전환 → 같은 장소 재선택 → 다른 장소 연속 선택 → 미리보기 재진입 순으로 확인 필요.

## 관련 코드

- [HomeViewModel](../../Maplog/Features/Home/ViewModels/HomeViewModel.swift) — 다운로드·시점 이동 ID와 재생 상태
- [AVVideoPlaybackService](../../Maplog/Features/Editor/Services/AVVideoPlaybackService.swift) — 영상 로딩·탐색·재생
- [HomeRoutePlaybackTests](../../MaplogTests/HomeRoutePlaybackTests.swift) — 취소·완료 순서·실패 상태
- [AVVideoPlaybackSeekTests](../../MaplogTests/AVVideoPlaybackSeekTests.swift) — 실제 AVFoundation 재생 검증

## 정리

화면에 같은 콘텐츠가 보여도 비동기 요청의 수명은 다를 수 있음. 콘텐츠 ID와 요청 ID를 분리하고 성공뿐 아니라 취소·실패·늦은 완료 이후의 상태까지 검증.
