import SwiftUI

struct ComposerView: View {
    @StateObject private var viewModel: ComposerViewModel

    init(initialSpot: MaplogSpot? = nil) {
        _viewModel = StateObject(wrappedValue: ComposerViewModel(initialSpot: initialSpot))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                    Text("새 기록")
                        .font(MaplogFont.largeTitle)
                        .tracking(-0.4)
                        .foregroundStyle(Color.maplogInk)
                    Text("사진과 감정, 별점으로 여행 순간을 정리해보세요.")
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogMuted)
                }

                TravelImageView(style: viewModel.selectedSpot?.imageStyle ?? .city, height: 210)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                            .foregroundStyle(Color.maplogOnPrimary)
                            .frame(width: 42, height: 42)
                            .background(Color.maplogLime)
                            .clipShape(Circle())
                            .padding(MaplogSpacing.small)
                    }

                placePicker
                moodPicker
                ratingPicker
                noteEditor

                NavigationLink {
                    LogPreviewView(draft: viewModel.draft)
                } label: {
                    HStack(spacing: MaplogSpacing.xSmall) {
                        Text("미리보기")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(MaplogButtonStyle(variant: .primary, size: .large, fullWidth: true))
            }
            .maplogPagePadding()
            .padding(.top, MaplogSpacing.pageTop)
            .padding(.bottom, MaplogSpacing.xxLarge)
        }
        .navigationTitle("기록하기")
        .navigationBarTitleDisplayMode(.inline)
        .maplogScreenSurface()
        .maplogNavigationAppearance()
    }

    private var placePicker: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SectionHeader(title: "장소")
            Menu {
                ForEach(MockMaplogData.spots) { spot in
                    Button(spot.name) {
                        viewModel.selectedSpot = spot
                    }
                }
            } label: {
                HStack {
                    MaplogPinGlyphIcon(size: MaplogSize.iconMedium)
                        .foregroundStyle(Color.maplogLime)
                    Text(viewModel.selectedSpot?.name ?? "장소 선택")
                        .font(MaplogFont.bodyStrong)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(MaplogFont.caption)
                }
                .foregroundStyle(Color.maplogInk)
                .padding(MaplogSpacing.medium)
                .maplogCard()
            }
        }
    }

    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SectionHeader(title: "오늘의 감정")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MaplogSpacing.xSmall) {
                    ForEach(viewModel.moods, id: \.self) { mood in
                        Button {
                            viewModel.selectedMood = mood
                        } label: {
                            ChipView(title: mood, isSelected: viewModel.selectedMood == mood)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var ratingPicker: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SectionHeader(title: "별점")
            HStack(spacing: MaplogSpacing.small) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        viewModel.rating = value
                    } label: {
                        Image(systemName: value <= viewModel.rating ? "star.fill" : "star")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(value <= viewModel.rating ? Color.maplogLime : Color.maplogLine)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SectionHeader(title: "메모")
            TextEditor(text: $viewModel.note)
                .font(MaplogFont.body)
                .foregroundStyle(Color.maplogInk)
                .frame(minHeight: 130)
                .padding(MaplogSpacing.small)
                .scrollContentBackground(.hidden)
                .maplogCard()
        }
    }
}
