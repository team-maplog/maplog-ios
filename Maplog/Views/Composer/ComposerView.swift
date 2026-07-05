import SwiftUI

struct ComposerView: View {
    @StateObject private var viewModel: ComposerViewModel

    init(initialSpot: MaplogSpot? = nil) {
        _viewModel = StateObject(wrappedValue: ComposerViewModel(initialSpot: initialSpot))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("새 기록")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                    Text("사진과 감정, 별점으로 여행 순간을 정리해보세요.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                }

                TravelImageView(style: viewModel.selectedSpot?.imageStyle ?? .city, height: 210)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                            .frame(width: 42, height: 42)
                            .background(Color.maplogLime)
                            .clipShape(Circle())
                            .padding(12)
                    }

                placePicker
                moodPicker
                ratingPicker
                noteEditor

                NavigationLink {
                    LogPreviewView(draft: viewModel.draft)
                } label: {
                    HStack {
                        Text("미리보기")
                            .fontWeight(.bold)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.maplogLime)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(MaplogSpacing.page)
            .padding(.bottom, 28)
        }
        .navigationTitle("기록하기")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.white)
    }

    private var placePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "장소")
            Menu {
                ForEach(MockMaplogData.spots) { spot in
                    Button(spot.name) {
                        viewModel.selectedSpot = spot
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Color.maplogLime)
                    Text(viewModel.selectedSpot?.name ?? "장소 선택")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .black))
                }
                .foregroundStyle(Color.maplogInk)
                .padding(14)
                .maplogCard()
            }
        }
    }

    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "오늘의 감정")
            HStack {
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

    private var ratingPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "별점")
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        viewModel.rating = value
                    } label: {
                        Image(systemName: value <= viewModel.rating ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundStyle(value <= viewModel.rating ? Color.maplogLime : Color.maplogLine)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "메모")
            TextEditor(text: $viewModel.note)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.maplogInk)
                .frame(minHeight: 130)
                .padding(10)
                .scrollContentBackground(.hidden)
                .maplogCard()
        }
    }
}
