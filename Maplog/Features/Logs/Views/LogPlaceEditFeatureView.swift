import SwiftUI

struct LogPlaceEditFeatureView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    @StateObject private var viewModel: LogPlaceEditViewModel

    let title: String
    let onConfirm: (LogLocationDraft) -> Void

    init(title: String, location: LogLocationDraft, repository: any LogLocationRepository,
         onConfirm: @escaping (LogLocationDraft) -> Void) {
        self.title = title
        self.onConfirm = onConfirm
        _viewModel = StateObject(wrappedValue: LogPlaceEditViewModel(location: location, repository: repository))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: MaplogSpacing.medium) {
                HStack {
                    TextField("장소명 또는 주소 검색", text: $viewModel.searchQuery)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .focused($isSearchFocused)
                        .onSubmit(search)
                    Button(action: search) {
                        Image(systemName: "magnifyingglass")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("장소 검색")
                }
                .padding(.leading, MaplogSpacing.medium)
                .background(Color.maplogSurfaceRaised, in: RoundedRectangle(cornerRadius: MaplogRadius.medium))

                ClipLocationPickerMap(location: viewModel.location) { latitude, longitude in
                    isSearchFocused = false
                    viewModel.select(LogLocationDraft(latitude: latitude, longitude: longitude))
                }
                .frame(height: max(160, min(340, geometry.size.height * 0.48)))
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.xLarge))
                .accessibilityLabel("장소 선택 지도")
                .accessibilityHint("지도를 움직여 중앙 핀의 위치를 변경하세요")

                ScrollView {
                    VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
                        Text("지도를 움직여 핀을 원하는 장소에 맞춰 주세요.")
                            .font(MaplogFont.caption)
                            .foregroundStyle(Color.maplogMuted)
                        if viewModel.isSearching { ProgressView("장소를 검색하고 있어요") }
                        if let message = viewModel.searchMessage {
                            Text(message).font(MaplogFont.caption).foregroundStyle(Color.maplogMuted)
                        }
                        ForEach(viewModel.searchResults, id: \.self) { result in
                            Button {
                                isSearchFocused = false
                                viewModel.select(result)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    MaplogLocationLabel(title: result.name ?? result.address ?? "장소", pinSize: 16)
                                        .font(MaplogFont.bodyStrong)
                                    if let address = result.address {
                                        Text(address).font(MaplogFont.caption).foregroundStyle(Color.maplogMuted)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("선택한 장소로 핀을 이동합니다")
                        }
                        Divider()
                        if viewModel.isResolving {
                            ProgressView("주소를 확인하고 있어요")
                        } else if let error = viewModel.locationError {
                            Text(error.message).font(MaplogFont.caption).foregroundStyle(Color.maplogDanger)
                            Button("주소 다시 확인") { viewModel.select(viewModel.location) }
                        } else {
                            MaplogLocationLabel(title: viewModel.location.name ?? "선택한 장소", pinSize: 18)
                                .font(MaplogFont.bodyStrong)
                            Text(viewModel.location.address ?? "주소를 확인해 주세요")
                                .font(MaplogFont.callout).foregroundStyle(Color.maplogMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, MaplogSpacing.medium)
                }
            }
            .maplogPagePadding()
            .padding(.top, MaplogSpacing.small)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .maplogScreenSurface()
        .maplogNavigationAppearance()
        .safeAreaInset(edge: .bottom) {
            PrimaryActionButton("이 장소 선택", isEnabled: viewModel.canConfirm) {
                guard viewModel.canConfirm else { return }
                onConfirm(viewModel.location)
                dismiss()
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.vertical, MaplogSpacing.small)
            .background(Color.maplogSurface)
        }
        .task { viewModel.resolveIfNeeded() }
        .onDisappear { viewModel.cancel() }
    }

    private func search() {
        isSearchFocused = false
        viewModel.search()
    }
}
