//
//  TourismDetailPhotoViewer.swift
//  Maplog
//
//  관광 상세 사진을 원본 비율로 크게 보여주는 전체 화면 뷰어
//

import SwiftUI

struct TourismDetailPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss

    let photos: [TourismDetailCarouselPhoto]
    let onPhotoSelectionChanged: (String) -> Void

    @State private var selectedPhotoID: String

    init(
        photos: [TourismDetailCarouselPhoto],
        initialPhotoID: String,
        onPhotoSelectionChanged: @escaping (String) -> Void
    ) {
        self.photos = photos
        self.onPhotoSelectionChanged = onPhotoSelectionChanged
        _selectedPhotoID = State(initialValue: initialPhotoID)
    }

    private var selectedPhotoIndex: Int {
        photos.firstIndex { $0.id == selectedPhotoID } ?? 0
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            TabView(selection: $selectedPhotoID) {
                ForEach(photos) { photo in
                    TourismDetailFullscreenPhoto(photo: photo)
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Spacer()

                    Button(action: dismissViewer) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(
                                width: MaplogSize.minimumTapTarget,
                                height: MaplogSize.minimumTapTarget
                            )
                            .background(.white.opacity(0.16), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("사진 크게 보기 닫기")
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, MaplogSpacing.small)

                Spacer()

                Text("\(selectedPhotoIndex + 1) / \(photos.count)")
                    .font(MaplogFont.calloutStrong)
                    .foregroundStyle(.white)
                    .padding(.horizontal, MaplogSpacing.small)
                    .padding(.vertical, MaplogSpacing.xSmall)
                    .background(.black.opacity(0.38), in: Capsule())
                    .padding(.bottom, MaplogSpacing.xxLarge)
            }
        }
        .onChange(of: selectedPhotoID) { _, photoID in
            onPhotoSelectionChanged(photoID)
        }
    }

    private func dismissViewer() {
        dismiss()
    }
}

private struct TourismDetailFullscreenPhoto: View {
    let photo: TourismDetailCarouselPhoto

    var body: some View {
        MaplogCachedRemoteImage(
            url: photo.imageURL,
            cacheKey: photo.cacheKey,
            targetSize: CGSize(width: 430, height: 932),
            contentMode: .fit
        ) {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(Color.maplogTextTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(photo.title ?? "관광지 사진")
    }
}
