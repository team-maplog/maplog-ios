# Maplog

**영상 속 장소와 이동 경로를 지도에 함께 기록하는 iOS 앱 (2026 관광데이터 활용 공모전)**

여행 영상만으로는 어느 장소에서 찍었는지, 어떤 순서로 이동했는지 다시 찾기 어려움. Maplog는 영상 클립에 장소·시간 정보를 연결해 지도에서 경로를 보고 해당 장면을 재생하는 흐름을 제공.

촬영 → 클립 편집 → 장소 확인 → 발행 → 지도·영상 탐색까지 iOS 앱에서 연결.

## 주요 기능

| 기능 | 사용자 흐름 |
| --- | --- |
| 촬영·편집 | 영상 촬영·가져오기, 클립 순서·구도·회전 조정, 자막·위치·시간 오버레이, 영상 내보내기 |
| 지도·영상 탐색 | 지도에서 게시물 탐색, 경로의 장소 선택, 해당 시점부터 영상 재생 |
| 맵로그 발행 | 커버·설명·태그 입력, 장소 검색·핀 조정, 발행·수정·삭제 |
| 관광 정보 | 축제·관광 목록, 카테고리 탐색, 상세 정보·사진·위치 확인 |
| 소셜·계정 | 이메일·소셜 로그인, 프로필·팔로우, 좋아요·댓글, 푸시 알림, 신고·차단 |

## 문제 해결

### 같은 관광 정보를 화면마다 다시 조회하던 문제

- **문제** — 홈·목록·상세에서 같은 정보를 반복 조회. 이미지 캐시가 있어도 이미지 주소를 얻는 상세 API 요청은 반복.
- **판단** — 여러 화면에서 재사용할 데이터이므로 공통 Repository에 캐시 배치. 사용자가 요청한 새로고침은 캐시와 구분.
- **해결** — 정상 응답을 10분간 메모리에 보관하고, 동시에 들어온 같은 요청은 진행 중인 Task 공유. 갱신 실패 시 기존 목록 유지.
- **검증** — 같은 키의 순차 요청 10회·동시 요청 10개에서 각각 로더 실행 1회를 확인하는 테스트. 만료·무효화·취소·커서 복구도 검증 대상.
- **범위** — 간헐적인 `502 / TOUR-002` 조사에서 발견한 앱의 반복 조회 개선. 외부 API 장애의 직접 원인과 운영 응답 시간 개선율은 미확정.

[캐시 위치·갱신 정책·검증 상세](docs/troubleshooting/tourism-response-cache.md)

### 여러 API가 동시에 만료 토큰으로 요청하는 상황

- **문제** — 홈의 여러 요청이 동시에 토큰 만료 응답을 받으면 재발급도 중복 실행될 수 있음.
- **판단** — 각 화면에 재로그인 처리를 넣으면 재시도·세션 종료 기준이 흩어짐. 인증 요청 처리와 토큰 재발급을 공통 계층에서 담당.
- **해결** — 진행 중인 재발급 Task를 공유하고, 토큰 교체 후 원래 요청을 한 번만 재시도. Access·Refresh Token은 Keychain에 저장.
- **검증** — 겹쳐 시작한 재발급 요청 3개에서 Repository 재발급 호출 1회·토큰 교체 1회를 확인하는 테스트.

[요청 흐름·책임 분리·검증 상세](docs/troubleshooting/token-refresh-coalescing.md)

### 지도에서 같은 영상을 다시 열었을 때 멈춘 미리보기

- **문제** — 다운로드 취소 후 영상 ID만 남아 준비 완료로 판단. 이전 다운로드·시점 이동 완료가 새 재생 요청에 반영될 가능성도 존재.
- **판단** — 영상 ID가 같아도 요청은 다를 수 있으므로 영상 식별과 요청 식별을 분리.
- **해결** — 다운로드·시점 이동마다 요청 ID를 확인하고, 재사용 전 실제 재생 항목 존재 여부 확인. 시점 이동 실패는 재시도 상태로 표시.
- **검증** — 취소 후 같은 영상 재요청, 늦게 끝난 이전 요청 무시, 마지막 장소 선택 우선 처리 테스트. 합성 로컬 영상으로 시점 이동 후 재생 진행도 확인.

[재현 조건·상태 처리·검증 상세](docs/troubleshooting/route-video-playback.md)

## 구조와 선택 이유

**MVVM + Repository + DI**

```mermaid
flowchart LR
    View[View] --> VM[ViewModel]
    VM --> Repo[Repository protocol]
    Repo --> Service[API Service protocol]
    Service --> Client[APIClient]
    Client --> Server[Backend]
```

| 위치 | 역할·분리 이유 |
| --- | --- |
| `Features/*/Views` | 화면 표시와 사용자 행동 전달. 서버 응답·인증 처리와 분리 |
| `Features/*/ViewModels` | 로딩·내용·빈 화면·실패 상태 관리. Repository를 대체해 화면 상태 검증 |
| `Features/*/Repositories` | DTO를 Domain Model로 변환. 화면 사이에서 데이터를 재사용하고 API 표현 차이를 흡수 |
| `Features/*/Services` | API 요청 구성 또는 촬영·재생·내보내기 등 플랫폼 기능 처리 |
| `Core` | 공통 네트워크·인증 역할·오류 타입·이미지 로딩 지원 |
| `MaplogApp.swift` | 구체 구현체 조립과 주입 |
| `MaplogTests` | Mock·Stub으로 정상·실패·동시 요청·취소 상황 검증 |

촬영·영상 편집은 ViewModel에서 Repository 또는 플랫폼 Service를 호출하는 별도 흐름. 모든 기능이 서버를 거치지는 않음.

## 기술

| 구분 | 사용 기술 |
| --- | --- |
| 화면 | Swift, SwiftUI, UIKit 연동 |
| 미디어·위치 | AVFoundation, Photos, CoreLocation, KakaoMapsSDK |
| 데이터·동시성 | URLSession, Codable, async/await, Task, actor |
| 인증·알림·이미지 | Keychain, AuthenticationServices, Firebase Messaging, Kingfisher |
| 검증 | XCTest, iOS Simulator |

## 실행

1. iOS 17.4 이상을 지원하는 Xcode에서 `Maplog.xcodeproj` 열기.
2. `Config/Secrets.xcconfig.example`을 `Config/Secrets.xcconfig`로 복사한 뒤 발급받은 Kakao 앱 키와 API 주소 설정.
3. Firebase 프로젝트의 iOS 설정 파일을 `Maplog/GoogleService-Info.plist`에 배치.
4. Swift Package 의존성 해석 후 실행 대상 선택. 실기기는 Signing Team과 Bundle ID 설정 필요.
5. `Maplog` 스킴 실행. 카카오 지도·소셜 로그인·푸시는 서비스 콘솔의 앱 등록 및 백엔드 설정 필요.

현재 의존성과 테스트 타깃은 Xcode 프로젝트 기준. `project.yml`에는 일부 구성이 반영되지 않아 XcodeGen 재생성 전 동기화 필요.

## 검증 범위

- 트러블슈팅 문서에 관련 코드·테스트와 재현 조건 연결.
- 테스트의 요청 횟수는 Mock·Stub 환경 기준. 운영 트래픽·응답 속도 개선 수치와 구분.
- 실제 기기의 지도 렌더링·네트워크 중단·소셜 로그인·푸시는 별도 확인 필요.
