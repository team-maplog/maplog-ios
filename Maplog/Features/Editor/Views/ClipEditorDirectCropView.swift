import SwiftUI

/// 손가락 이동 중에는 정지 프레임만 움직이고, 완료 시 실제 영상 구도를 한 번 반영한다.
struct ClipEditorDirectCropView: View {
    let configuration: VideoCompositionConfiguration
    let clipIDs: [UUID]
    let selectedID: UUID?
    let frameData: Data?
    let isUpdating: Bool
    let onSelect: (UUID) -> Void
    let onCommit: (UUID, VideoClipCrop) -> Void

    var body: some View {
        GeometryReader { proxy in
            let scene = configuration.sceneFrame(in: proxy.size)
            let frames = configuration.layout.normalizedFrames(for: configuration.sceneOrientation)
            ForEach(Array(clipIDs.enumerated()), id: \.element) { index, id in
                if frames.indices.contains(index) {
                    let slot = frames[index]
                    ClipCropSlotView(
                        crop: configuration.clipCrops[id] ?? VideoClipCrop(),
                        image: selectedID == id ? frameData.flatMap(UIImage.init(data:)) : nil,
                        isSelected: selectedID == id,
                        isUpdating: isUpdating,
                        fillsSlot: configuration.layout != .single,
                        onSelect: { onSelect(id) },
                        onCommit: { onCommit(id, $0) }
                    )
                    .frame(width: slot.width * scene.width, height: slot.height * scene.height)
                    .position(x: scene.minX + slot.midX * scene.width, y: scene.minY + slot.midY * scene.height)
                }
            }
        }
    }
}

private struct ClipCropSlotView: View {
    let crop: VideoClipCrop
    let image: UIImage?
    let isSelected: Bool
    let isUpdating: Bool
    let fillsSlot: Bool
    let onSelect: () -> Void
    let onCommit: (VideoClipCrop) -> Void
    @State private var draft: VideoClipCrop?

    var body: some View {
        GeometryReader { proxy in
            let value = draft ?? crop
            ZStack {
                Color.clear
                if isSelected, let image {
                    let rotatedSize = value.quarterTurns % 2 == 0
                        ? image.size : CGSize(width: image.size.height, height: image.size.width)
                    let bounds = CGRect(origin: .zero, size: rotatedSize)
                    let rect = fillsSlot
                        ? value.sourceRect(in: bounds, destinationAspectRatio: proxy.size.width / proxy.size.height)
                        : bounds
                    let scale = min(proxy.size.width / rect.width, proxy.size.height / rect.height)
                    Color.black
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: image.size.width * scale, height: image.size.height * scale)
                        .rotationEffect(.degrees(Double(value.quarterTurns) * 90))
                        .frame(width: rotatedSize.width * scale, height: rotatedSize.height * scale)
                        .offset(x: (bounds.midX - rect.midX) * scale, y: (bounds.midY - rect.midY) * scale)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { if !isUpdating { onSelect() } }
            .gesture(DragGesture(minimumDistance: 4)
                .onChanged { gesture in
                    guard isSelected, !isUpdating, fillsSlot, let image else { return }
                    let size = crop.quarterTurns % 2 == 0
                        ? image.size : CGSize(width: image.size.height, height: image.size.width)
                    draft = crop.moved(by: gesture.translation, sourceSize: size, slotSize: proxy.size)
                }
                .onEnded { _ in
                    if let draft { onCommit(draft) }
                    draft = nil
                }
            )
            .overlay {
                if isSelected {
                    Rectangle().strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    Button {
                        onCommit(VideoClipCrop(horizontalPosition: 0.5, verticalPosition: 0.5,
                                               zoom: crop.zoom, quarterTurns: crop.quarterTurns + 1))
                    } label: {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdating || image == nil)
                    .accessibilityLabel("선택한 영상 시계 방향으로 90도 회전")
                    .padding(10)
                }
            }
            .accessibilityAction(named: "영상 선택", onSelect)
        }
    }
}
