import AVFoundation
import SwiftUI

/// 선택한 클립의 구도를 조절한다. 손을 놓을 때만 합성을 다시 만들어 슬라이더 입력을 막지 않는다.
struct ClipEditorCropView: View {
    @ObservedObject var viewModel: ClipEditorViewModel
    let player: AVPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var selectedClipID: UUID?
    @State private var horizontalPosition = 0.5
    @State private var verticalPosition = 0.5
    @State private var zoom = 1.0
    @State private var isSubmittingCrop = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: MaplogSpacing.small) {
                    MaplogVideoPlayerLayerView(player: player, videoGravity: .resizeAspect)
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity)
                        .frame(height: max(120, geometry.size.height - 290))
                        .background(.black)

                    ScrollView {
                        VStack(spacing: MaplogSpacing.small) {
                            Picker("조정할 클립", selection: $selectedClipID) {
                                ForEach(Array(viewModel.timelineItems.enumerated()), id: \.element.id) { index, item in
                                    Text("클립 \(index + 1)").tag(Optional(item.id))
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: selectedClipID) { _, _ in loadSelectedCrop() }

                            adjustment("가로 위치", value: $horizontalPosition, range: 0...1)
                            adjustment("세로 위치", value: $verticalPosition, range: 0...1)
                            adjustment("확대", value: $zoom, range: 1...3)

                            if let error = viewModel.cropError {
                                Text(error.message)
                                    .font(MaplogFont.caption)
                                    .foregroundStyle(Color.maplogDanger)
                            }
                            HStack {
                                Text((viewModel.isUpdatingCrop || isSubmittingCrop) ? "미리보기 반영 중…" : "손을 놓으면 미리보기에 반영돼요")
                                    .font(MaplogFont.caption)
                                    .foregroundStyle(Color.maplogTextSecondary)
                                Spacer()
                                Button("원래 구도") {
                                    horizontalPosition = 0.5
                                    verticalPosition = 0.5
                                    zoom = 1
                                    applyCrop()
                                }
                            }
                        }
                        .padding(.horizontal, MaplogSpacing.page)
                        .disabled(viewModel.isUpdatingCrop || isSubmittingCrop)
                    }
                }
            }
            .navigationTitle("분할 영역 조정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                        .disabled(viewModel.isUpdatingCrop || isSubmittingCrop)
                }
            }
            .background(Color.maplogSurface)
            .interactiveDismissDisabled(viewModel.isUpdatingCrop || isSubmittingCrop)
            .onAppear {
                viewModel.setOverlayDragging(true)
                selectedClipID = viewModel.selectedPreview?.id ?? viewModel.timelineItems.first?.id
                loadSelectedCrop()
            }
            .onDisappear { viewModel.setOverlayDragging(false) }
        }
    }

    private func adjustment(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title).font(MaplogFont.callout).frame(width: 66, alignment: .leading)
            Slider(value: value, in: range) { isEditing in
                if !isEditing { applyCrop() }
            }
            .tint(.maplogLime)
            .accessibilityLabel(title)
            Text(title == "확대" ? String(format: "%.1f×", value.wrappedValue) : String(format: "%.0f%%", value.wrappedValue * 100))
                .font(MaplogFont.caption)
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)
        }
        .frame(minHeight: MaplogSize.minimumTapTarget)
    }

    private func loadSelectedCrop() {
        guard let selectedClipID else { return }
        let crop = viewModel.crop(for: selectedClipID)
        horizontalPosition = crop.horizontalPosition
        verticalPosition = crop.verticalPosition
        zoom = crop.zoom
    }

    private func applyCrop() {
        guard let selectedClipID, !isSubmittingCrop else { return }
        isSubmittingCrop = true
        let crop = VideoClipCrop(horizontalPosition: horizontalPosition, verticalPosition: verticalPosition, zoom: zoom)
        Task {
            await viewModel.updateCrop(crop, for: selectedClipID)
            loadSelectedCrop()
            isSubmittingCrop = false
        }
    }
}
