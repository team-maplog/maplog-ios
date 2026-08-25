//
//  TourismDetailPhotoCarousel.swift
//  Maplog
//
//  관광 상세의 대표 이미지와 추가 이미지를 한 흐름으로 보여주는 사진 캐러셀
//

import SwiftUI

struct TourismDetailPhotoCarousel: View {
    let heroImageURL: URL?
    let images: [TourismDetailImageViewData]
    let onBack: () -> Void

    @State private var selectedPhotoID: String?
    @State private var selectedPhotoForPreview: TourismDetailCarouselPhoto?

    private var photos: [TourismDetailCarouselPhoto] {
        var photoItems: [TourismDetailCarouselPhoto] = []
        var addedURLs = Set<String>()

        if let heroImageURL {
            photoItems.append(
                TourismDetailCarouselPhoto(
                    id: "hero-\(heroImageURL.absoluteString)",
                    imageURL: heroImageURL,
                    title: nil
                )
            )
            addedURLs.insert(heroImageURL.absoluteString)
        }

        for image in images where addedURLs.insert(image.imageURL.absoluteString).inserted {
            photoItems.append(
                TourismDetailCarouselPhoto(
                    id: image.id,
                    imageURL: image.imageURL,
                    title: image.title
                )
            )
        }

        return photoItems
    }

    private var activePhotoID: String? {
        selectedPhotoID ?? photos.first?.id
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            carouselContent

            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(
                        width: MaplogSize.minimumTapTarget,
                        height: MaplogSize.minimumTapTarget
                    )
                    .background(.black.opacity(0.28), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.35), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로가기")
            .padding(.leading, MaplogSpacing.page)
            // 포스터의 좌·상단 선과 버튼의 좌·상단 선을 맞춘다.
            // 44pt 터치 영역과 좌우 16pt 여백은 다른 화면의 뒤로가기 버튼과 동일하다.
            .padding(.top, 0)
        }
        .frame(height: 340)
        .onAppear {
            selectedPhotoID = selectedPhotoID ?? photos.first?.id
        }
        .fullScreenCover(item: $selectedPhotoForPreview) { photo in
            TourismDetailPhotoViewer(
                photos: photos,
                initialPhotoID: photo.id,
                onPhotoSelectionChanged: updateSelectedPhoto
            )
        }
    }

    @ViewBuilder
    private var carouselContent: some View {
        if photos.isEmpty {
            TourismDetailPhotoPlaceholder()
        } else {
            GeometryReader { proxy in
                let photoWidth = max(
                    1,
                    proxy.size.width - (MaplogSpacing.page * 2) - MaplogSpacing.small
                )

                ScrollView(.horizontal) {
                    LazyHStack(spacing: MaplogSpacing.small) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            TourismDetailCarouselPhotoView(
                                photo: photo,
                                position: index + 1,
                                totalCount: photos.count,
                                onSelect: { presentPhoto(photo) }
                            )
                            .frame(width: photoWidth, height: proxy.size.height)
                            .id(photo.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $selectedPhotoID)
                .contentMargins(.horizontal, MaplogSpacing.page, for: .scrollContent)
                .overlay(alignment: .bottom) {
                    if photos.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(photos) { photo in
                                Capsule()
                                    .fill(
                                        photo.id == activePhotoID
                                        ? Color.white
                                        : Color.white.opacity(0.45)
                                    )
                                    .frame(
                                        width: photo.id == activePhotoID ? 16 : 6,
                                        height: 6
                                    )
                            }
                        }
                        .padding(.horizontal, MaplogSpacing.small)
                        .padding(.vertical, MaplogSpacing.xSmall)
                        .background(.black.opacity(0.22), in: Capsule())
                        .padding(.bottom, MaplogSpacing.small)
                    }
                }
            }
        }
    }

    private func presentPhoto(_ photo: TourismDetailCarouselPhoto) {
        selectedPhotoForPreview = photo
    }

    private func updateSelectedPhoto(_ photoID: String) {
        selectedPhotoID = photoID
    }
}

struct TourismDetailCarouselPhoto: Identifiable {
    let id: String
    let imageURL: URL
    let title: String?
}

private struct TourismDetailCarouselPhotoView: View {
    let photo: TourismDetailCarouselPhoto
    let position: Int
    let totalCount: Int
    let onSelect: () -> Void

    var body: some View {
        AsyncImage(url: photo.imageURL) { phase in
            switch phase {
            case .empty:
                TourismDetailPhotoPlaceholder()
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }

            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()

            case .failure:
                TourismDetailPhotoPlaceholder()

            @unknown default:
                TourismDetailPhotoPlaceholder()
            }
        }
        .background(Color.black)
        .clipShape(
            RoundedRectangle(
                cornerRadius: MaplogRadius.hero,
                style: .continuous
            )
        )
        .accessibilityLabel(photo.title ?? "관광지 사진")
        .accessibilityValue("사진 \(position) / \(totalCount)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("두 번 탭하면 사진을 크게 봅니다")
        .contentShape(
            RoundedRectangle(
                cornerRadius: MaplogRadius.hero,
                style: .continuous
            )
        )
        .onTapGesture(perform: onSelect)
    }
}

private struct TourismDetailPhotoPlaceholder: View {
    var body: some View {
        Color.maplogSurfaceRaised
            .overlay {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(Color.maplogTextTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
