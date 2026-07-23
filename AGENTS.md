# Maplog 작업 가이드

## 1. 사용자와 협업 방식

- 이 프로젝트의 사용자는 iOS 신입 개발자 취업을 준비하며, Maplog를 포트폴리오로 발전시키고 있다.
- 기본 언어는 한국어다. 설명은 결론부터 말하고, 쉬운 비유와 실제 코드 흐름을 함께 사용한다.
- 기본 동작은 **티칭 모드**다. 개념 → 역할 분리 → 작업 위치 → 코드 한 조각 → 확인 방법 순서로 단계적으로 안내한다.
- 사용자가 이해하지 못한 문법이나 용어(`any`, `Hashable`, DI, cursor, `@StateObject` 등)는 건너뛰지 말고, 더 작은 예시로 다시 설명한다.
- 사용자가 명시적으로 구현을 요청하지 않는 한 구현 소스 파일을 직접 수정하지 않는다. 진단·리뷰·설명 요청은 읽기 전용으로 처리한다.
- 사용자가 명시적으로 허용한 문서·Git 작업은 요청 범위 안에서 직접 수행할 수 있다. 코드를 수정할 때도 먼저 변경 범위와 검증 방법을 알린다.
- 기존 목업 코드는 구조 판단의 기준으로 삼지 않는다. 새 기능은 아래의 아키텍처 규칙을 우선한다.

## 2. 아키텍처: MVVM + Repository + DI

### 역할 분리

- **View**: 화면을 그리고 사용자 행동을 ViewModel에 전달한다. URL, HTTP, JSON, Keychain, 비즈니스 규칙을 모른다.
- **ViewModel**: 화면 상태, 로딩, 사용자 행동, 화면용 ViewData를 관리한다. SwiftUI 화면 자체나 URLRequest를 만들지 않는다.
- **Repository**: API DTO를 앱 Domain Model로 변환하고, 앱에 필요한 데이터 경계를 제공한다. SwiftUI와 화면 문구를 모른다.
- **API Service**: endpoint, URLRequest, header, JSON DTO, APIClient 호출을 담당한다.
- **Core Networking / Error Policy**: 공통 응답·오류를 해석하고, feature별 화면 정책으로 변환한다.

### 의존성 주입

- 구체 구현체는 Composition Root(`MaplogApp`)에서만 조립한다.
- ViewModel은 Repository protocol에, Repository는 API Service protocol에 의존한다.
- Service가 인증 토큰이 필요하면 `AuthSessionStore` 구체 타입이 아니라 `AccessTokenProviding` 같은 역할 protocol에 의존한다.
- `Default...` 구현체의 이름과 생성은 조립 지점에만 두고, 하위 계층에는 protocol을 주입한다.

### 데이터와 오류 규칙

- 서버 JSON DTO와 앱 Domain Model은 분리한다. 서버 키와 Swift 이름이 다르면 `CodingKeys`로 명시적으로 연결한다.
- HTTP 상태, `successFlag`, 서버 `code`를 함께 해석한다. 화면 분기는 `message` 문자열이 아니라 서버 `code`를 기준으로 한다.
- `APIError`, `APIErrorResponse`, `BackendErrorCode`는 공통 계층에 둔다.
- feature별 `...ErrorPolicy`는 기술 오류를 `ErrorPresentation(message, recoveryAction)`으로 바꾼다.
- 첫 페이지 오류와 다음 페이지 오류를 분리한다. 이미 표시한 목록은 다음 페이지 실패 때문에 지우지 않는다.
- JWT Access/Refresh Token은 Keychain에만 저장하고, 로그·콘솔·PR 본문·스크린샷·소스에 절대 출력하거나 커밋하지 않는다.
- 인증되지 않은 요청과 인증 요청의 규칙이 다르므로 `APIClient`가 모든 요청에 Authorization 헤더를 자동으로 붙이지 않는다.

## 3. 인증과 API 계약

- API 구현 전 Swagger와 사용 가이드를 확인한다. endpoint, HTTP method, request body, success `code`, response `data`, 오류 `code`를 추측하지 않는다.
- 성공/실패 코드는 HTTP 200만으로 판단하지 않는다. Maplog API는 `successFlag`와 application code를 함께 사용한다.
- 로그인 성공은 `SUCCESS-006`, 회원가입 성공은 `SUCCESS-005`다. JWT 재발급은 `SUCCESS-007`이다.
- `COMMON-014`는 field별 오류 배열을 포함할 수 있으므로 해당 입력 UI에 연결한다.
- `WRONG_TOKEN`, `MALFORMED_JWT`, `UNSUPPORTED_JWT`, `ILLEGAL_ARGUMENT_JWT`, `REFRESH_INVALID`은 세션 종료 후 로그인으로 연결한다.
- `EXPIRED_TOKEN`은 재발급 계약이 구현된 뒤에만 한 번 재발급을 시도한다. 무한 재시도하지 않는다.
- `CURSOR-001`은 다음 페이지 요청을 중단하고 첫 페이지부터 다시 조회한다.

## 4. 포트폴리오·신입 iOS 역량 기준

### 지속 원칙

- 취업 역량 또는 최신 iOS 권장 사항을 말할 때는 먼저 최신 공식 문서, 기업 채용 페이지, 또는 실제 채용 플랫폼 공고를 확인한다.
- 공고가 경력직인지 신입/경력인지 구분해서 설명한다. 경력직 요구 사항을 신입 필수 요건처럼 말하지 않는다.
- 공고는 마감·변경될 수 있다. 과거 스냅샷은 방향을 잡는 근거일 뿐, 지원 직전에는 원문을 다시 확인한다.
- 포트폴리오 기능은 단순 화면 구현보다 설계 이유, API 계약, 오류 처리, 테스트·검증, 협업 기록(PR)을 보여 주도록 만든다.

### 2026-07-24 채용 조사 스냅샷

아래는 당시 공개되어 있던 실제 공고·공식 문서를 읽어 도출한 기준이다. 상태와 마감일은 변할 수 있으므로 인용 전 원문을 재확인한다.

- 신입 공고는 Swift 기본기, 모듈 분할을 통한 문제 해결, 코드 리뷰·커뮤니케이션을 요구하거나 우대했다.
  - [째깍악어 신입 iOS 개발자](https://jumpit.saramin.co.kr/position/42733390)
  - [라온시큐어 신입 iOS 개발](https://jumpit.saramin.co.kr/position/50141112/)
- 신입 공고에서도 Git 협업, 지도·로그인·UI 커스터마이징, App Store 배포 경험처럼 완결된 앱 경험을 요구했다.
  - [러닝포인트 iOS 러닝 앱 개발자 신입](https://jumpit.saramin.co.kr/position/52614635)
- 신입/경력 공고에서는 SwiftUI, MVVM, 객체지향 이해, 코드 리뷰와 자동화 아이디어가 함께 언급됐다.
  - [피피프렌즈 신입/경력 iOS 개발자](https://jumpit.saramin.co.kr/position/46748107)
- 공식 Apple 문서는 Swift·SwiftUI뿐 아니라 HIG, 개인정보·Keychain, 손쉬운 사용, 디버깅, Instruments 성능 분석을 iOS 개발의 핵심 실무 범위로 제시한다.
  - [Apple iOS Pathway](https://developer.apple.com/kr/ios/get-started/)
  - [WWDC26 하이라이트](https://developer.apple.com/kr/wwdc26/guides/highlights/)

### 이 프로젝트에서 증명할 역량

1. Swift 언어 기본기, Optional·Error·Protocol·value/reference semantics·Swift Concurrency를 설명하고 적용한다.
2. SwiftUI를 중심으로 만들되 UIKit·HIG·접근성의 기본 개념도 이해한다.
3. REST API, Codable DTO, HTTP/application code, JWT, Keychain, pagination cursor를 안전하게 다룬다.
4. MVVM + Repository + DI로 관심사를 분리하고 Mock Repository로 ViewModel을 검증할 수 있게 만든다.
5. Git 브랜치·PR·코드 리뷰·명확한 커밋으로 협업 과정을 남긴다.
6. Build, 단위 테스트, UI 상태 확인, 실패 시나리오, 성능·메모리 점검을 기능 완료 기준에 포함한다.

## 5. Git과 PR 작업 흐름

### 브랜치 전략

- `main`: Production 안정 버전. 직접 push하지 않는다.
- `develop`: Dev 통합 브랜치. 직접 push하지 않는다.
- `feat/*`: 기능, `fix/*`: 버그, `hotfix/*`: 운영 긴급 수정, `docs/*`: 문서, `chore/*`: 설정·기타.
- 한 브랜치·커밋·PR에는 가능한 한 하나의 기능 또는 수정만 담는다.

### 작업 시작

새 기능 시작 전 다음 순서를 기본으로 한다.

```bash
git fetch origin --prune
git switch develop
git pull --ff-only origin develop
git switch -c feat/<feature-name>
```

- `git pull --ff-only`를 사용해 자동 merge commit이나 조용한 브랜치 꼬임을 피한다.
- 충돌·divergence·범위가 불명확한 변경이 있으면 임의로 reset, checkout, stash, force push하지 말고 사용자에게 설명한다.
- API 계약 변경은 구현 전에 프론트엔드와 백엔드 명세를 함께 확인한다.

### 커밋과 PR

- 변경 전후에 `git status`, `git diff`, `git diff --check`로 범위와 공백 오류를 확인한다.
- 관련 파일만 명시적으로 stage한다. 범위가 섞였을 때 `git add -A`를 사용하지 않는다.
- 민감값, Keychain 값, 토큰, 비밀번호, API Key, 환경 변수 파일은 커밋하지 않는다.
- 커밋은 Conventional Commits를 사용한다. 예: `feat: 로그인 API 연동`.
- PR에는 작업 내용, 변경 사항, 관련 이슈, 검증 결과, 미검증 항목을 사실대로 작성한다.
- 기본적으로 feature PR은 draft로 만들고, build·diff·아키텍처·오류 정책·민감값을 검토한 뒤 준비 완료로 전환한다.
- 병합은 `feature → develop` PR, 이후 배포 시점의 `develop → main` PR 순서로 한다. `main` 병합은 매번 사용자의 명시적 최종 확인을 받는다.

## 6. 기능 완료 전 점검표

- [ ] API 계약과 성공·오류 code를 원문 기준으로 반영했는가?
- [ ] View / ViewModel / Repository / Service 책임이 섞이지 않았는가?
- [ ] Loading / content / empty / failed 상태와 재시도 동작이 있는가?
- [ ] 인증·입력·네트워크·서버 오류를 중앙 정책과 feature 정책으로 처리했는가?
- [ ] 토큰·비밀번호 등 민감 정보가 노출되지 않았는가?
- [ ] 실제 API 또는 명시적인 Mock으로 정상·실패 흐름을 검증했는가?
- [ ] Simulator 빌드와 관련 테스트를 실행했는가?
- [ ] 변경 범위에 맞는 커밋·PR·검토 기록을 남겼는가?
