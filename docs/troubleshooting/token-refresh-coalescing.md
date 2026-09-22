# 동시에 만료된 요청의 토큰 재발급 공유

## 문제

- 홈 진입 시 여러 API 요청이 겹칠 수 있는 구조.
- 각 요청이 만료 응답마다 재발급을 시작하면 같은 세션의 토큰을 중복 교체할 가능성.
- 화면마다 처리할 경우 재시도 횟수와 세션 종료 기준을 일관되게 유지하기 어려움.

## 판단과 선택

- **인증 요청 처리 분리** — `AuthenticatedAPIClient`가 Access Token 첨부·만료 응답·재시도 담당. 일반 `APIClient`는 모든 요청에 인증 헤더를 붙이지 않음.
- **진행 중 작업 공유** — `DefaultAccessTokenRefresher`가 재발급 Task 하나를 보관. 겹쳐 들어온 호출은 같은 Task의 완료를 기다림.
- **재시도 상한 설정** — `EXPIRED_TOKEN`이면 재발급 후 원래 요청을 한 번만 재시도. 반복 재귀 호출 방지.
- **저장 책임 분리** — Refresher는 `AuthSessionManaging`에 토큰 교체 요청. 실제 저장은 `AuthSessionStore`와 Keychain 담당.

`@MainActor`로 Refresher 상태 접근을 직렬화해도 `await` 중에는 다른 호출이 진입 가능. `refreshTask`를 등록한 뒤 기다리는 순서가 중복 재발급을 막는 기준.

## 처리 흐름

```text
View → ViewModel → 기능 Repository → API Service
  → AuthenticatedAPIClient → APIClient
  → EXPIRED_TOKEN
  → AccessTokenRefresher: 진행 중 Task 확인
      있음: 기존 Task 대기
      없음: AuthRepository.reissueToken() → 토큰 교체
  → 원래 요청 재시도 1회
```

- 재발급 성공·실패 후 `defer`에서 Task 참조 정리.
- 토큰 오류가 세션 종료 대상이면 `AuthSessionLifecycleManaging`에 종료 요청.
- HTTP 상태와 서버 오류 코드를 사용하며 오류 메시지 문자열로 분기하지 않음.
- Access·Refresh Token은 Keychain 저장. View와 ViewModel이 Keychain API를 직접 호출하지 않는 구조.

## 검증

2026-09-22 iOS Simulator에서 `DefaultAccessTokenRefresherTests`의 **1개 테스트 통과**.

| 조건 | 확인 결과 |
| --- | --- |
| `async let`으로 재발급 호출 3개 시작 | 세 호출 모두 정상 완료 |
| 지연을 둔 AuthRepository Spy | 재발급 호출 1회 |
| AuthSession Spy | 토큰 교체 1회 |

이 테스트는 **재발급 작업이 겹치는 동안의 공유**를 검증. 재발급 종료 후 늦게 도착한 이전 만료 응답, 로그아웃과 재발급의 경합, 실제 서버의 토큰 회전 정책까지 보장하는 테스트는 아님. 해당 시나리오는 별도 검증 필요.

## 관련 코드

- [AuthenticatedAPIClient](../../Maplog/Core/Networking/AuthenticatedAPIClient.swift) — 인증 헤더·만료 응답·재시도
- [DefaultAccessTokenRefresher](../../Maplog/Features/Auth/Services/DefaultAccessTokenRefresher.swift) — 진행 중 재발급 공유
- [AuthSessionStore](../../Maplog/Stores/AuthSessionStore.swift) — 세션 상태·토큰 교체
- [KeychainService](../../Maplog/Services/KeychainService.swift) — 토큰 저장·조회·삭제
- [DefaultAccessTokenRefresherTests](../../MaplogTests/DefaultAccessTokenRefresherTests.swift) — 중복 호출 검증

## 정리

동시성 처리에서 확인할 대상은 공유 변수 접근뿐 아니라 실제로 실행되는 요청 횟수. 인증 복구를 공통 계층에 두고 호출 횟수·토큰 교체 횟수를 함께 검증.
