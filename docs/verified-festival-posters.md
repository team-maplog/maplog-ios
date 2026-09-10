# 홈·상세의 확인된 축제 포스터

## 표시 규칙

- 홈: 포스터가 확인된 축제만 표시한다. 일반 사진·추가 이미지를 대신 사용하지 않는다.
- 상세: 홈과 같은 확인된 포스터 → 기존 대표 사진 → 추가 사진 순서다. 같은 이미지 URL은 한 번만 표시한다.
- 전체보기: 포스터가 없는 축제도 계속 조회할 수 있다. 이 경로의 상세에서는 기존 사진을 볼 수 있다.
- 홈 포스터 다운로드 실패: 해당 카드를 제외한다. 새로고침하면 다시 시도한다.
- 홈에 표시할 항목이 없으면 빈 상태를 보여준다.

## 현재 등록 상태

실제 축제 ID·행사 기간·포스터 원본 URL을 함께 확인한 등록 항목은 아직 없다.
`VerifiedTourismPosters.entries`는 빈 배열이며, 등록 전에는 홈 축제 목록이 비어 있는 것이 의도된 동작이다.
테스트의 example.invalid 주소는 운영 데이터가 아니다.

## 등록 위치와 확인 절차

`Maplog/Features/Tourisms/Repositories/VerifiedTourismPosterCatalog.swift`의 `VerifiedTourismPosters.entries`에 등록한다.

1. 축제의 `tourismId`와 해당 회차의 시작일·종료일을 실제 API에서 확인한다.
2. 이미지 원본을 직접 열어 해당 축제·회차의 포스터인지 확인한다. 대표 이미지라는 이유나 세로 비율만으로 승인하지 않는다.
3. 확인한 원본 URL과 행사 기간을 하나의 `VerifiedTourismPoster`로 등록한다.
4. 홈과 상세 첫 장이 같은 이미지인지, 관련 사진이 이후에 보이는지 확인한다.

등록 형식(아래 값은 예시이므로 그대로 운영 목록에 추가하지 않는다):

```swift
VerifiedTourismPoster(
    tourismID: 123,
    imageURL: URL(string: "https://example.invalid/verified-poster.jpg")!,
    eventStartDate: "2026-09-09",
    eventEndDate: "2026-09-10"
)
```

날짜는 서울 기준 `yyyy-MM-dd`다. ID가 같더라도 기간이 다르거나, 동일 행사에 여러 항목이 등록돼 선택이 모호하면 사용하지 않는다. 기간이 변경되면 재확인 후 등록 정보도 수정한다. 이미지가 다른 URL로 제공되면 같은 사진이라도 자동으로 동일 사진이라고 추측하지 않는다.

## 구조

`MaplogApp`이 `VerifiedTourismPosterProviding`을 구현한 로컬 등록 목록을 `DefaultTourismRepository`에 주입한다. Repository가 목록·상세 Domain Model의 `verifiedPosterURL`을 채운다. HomeViewModel은 확인된 포스터 목록을 요청하고, TourismDetailViewModel은 포스터 우선 순서와 중복 제거를 담당한다. View는 전달받은 이미지와 순서를 표시한다.

홈 조회는 기존 관광 목록 API를 사용한다. 확인된 항목이 첫 페이지에 없으면 다음 페이지를 조회하며, 필요한 개수를 확보하거나 등록된 ID를 모두 확인하면 중단한다. 잘못된 반복 cursor는 중단한다. 빈 등록 목록에는 추가 API 요청을 하지 않는다.

## 서버 연동으로 전환할 때

현재 서버 모델의 `originalImageUrl`, `thumbnailUrl`, 추가 이미지 `name`은 포스터 검수 완료를 뜻하지 않는다. 확인하지 않은 서버 필드를 DTO에 임의로 추가하지 않았다.

로컬 등록은 앱 업데이트가 필요하다. 운영 중 포스터를 수시로 추가하려면 서버에 검수된 포스터의 축제 ID·행사 기간·원본 URL을 관리하는 API 계약을 먼저 추가하고, 그 계약에 맞는 데이터 공급자로 교체한다. 등록 데이터 없이 모든 축제를 자동으로 포스터라고 판단하는 기능은 포함하지 않는다.
