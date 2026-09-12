import MapKit
import SwiftUI

/// 중앙 핀 아래의 좌표를 선택합니다. 검색 이동과 손으로 옮긴 이동을 구분합니다.
struct ClipLocationPickerMap: View {
    let location: LogLocationDraft
    let onLocationSelected: (Double, Double) -> Void

    @State private var position: MapCameraPosition
    @State private var visibleRegion: MKCoordinateRegion

    init(
        location: LogLocationDraft,
        onLocationSelected: @escaping (Double, Double) -> Void
    ) {
        self.location = location
        self.onLocationSelected = onLocationSelected
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            latitudinalMeters: 1_000,
            longitudinalMeters: 1_000
        )
        _position = State(initialValue: .region(region))
        _visibleRegion = State(initialValue: region)
    }

    var body: some View {
        Map(position: $position, interactionModes: [.pan, .zoom])
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                // 검색 결과로 이동한 카메라를 손으로 옮긴 것으로 처리하면 장소명이 지워집니다.
                guard position.positionedByUser,
                      abs(context.region.center.latitude - location.latitude) > 0.000001
                        || abs(context.region.center.longitude - location.longitude) > 0.000001 else { return }
                onLocationSelected(context.region.center.latitude, context.region.center.longitude)
            }
            .onChange(of: location) { _, location in
                let center = visibleRegion.center
                // 주소만 갱신되거나 사용자가 옮긴 좌표가 돌아온 경우 카메라를 다시 움직이지 않습니다.
                guard abs(center.latitude - location.latitude) > 0.000001
                    || abs(center.longitude - location.longitude) > 0.000001 else { return }
                let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                    span: visibleRegion.span
                )
                visibleRegion = region
                position = .region(region)
            }
            .overlay {
                MaplogPinGlyphIcon(size: 30)
                    .foregroundStyle(Color.maplogInk)
                    .shadow(color: .black.opacity(0.24), radius: 4, y: 2)
                    .offset(y: -15)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}
