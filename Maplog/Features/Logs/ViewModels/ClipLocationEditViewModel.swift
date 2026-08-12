//
//  ClipLocationEditViewModel.swift
//  Maplog
//
//  Created by 한채림 on 8/9/26.
// 장소 수정

import Foundation

@MainActor
final class ClipLocationEditViewModel: ObservableObject {
    @Published private(set) var selectedLocation: LogLocationDraft?
    @Published private(set) var isResolvingLocation = false
    @Published private(set) var locationResolutionError: ErrorPresentation?

    private let originalClipLocation: LogComposeClipLocationDraft
    private let logLocationRepository: any LogLocationRepository

    private var locationResolutionTask: Task<Void, Never>?

    init(
        clipLocation: LogComposeClipLocationDraft,
        logLocationRepository: any LogLocationRepository
    )
    {
        self.originalClipLocation = clipLocation // 처음 카드에서 전달받은 원본
        self.selectedLocation = clipLocation.location  // 사용자가 수정 중인 임시 값
        self.logLocationRepository = logLocationRepository
    }

    var timeRangeText: String {
        "\(timelineTimeText(originalClipLocation.startTime))–\(timelineTimeText(originalClipLocation.endTime))"
    }

    var locationText: String {
            guard let selectedLocation else {
                return "장소를 선택해 주세요"
            }

            if isResolvingLocation {
                return "주소를 확인하고 있어요"
            }

            return selectedLocation.name
                ?? selectedLocation.address
                ?? "주소를 찾지 못했어요"
        }

    var canRestoreCapturedLocation: Bool {
        originalClipLocation.location != nil
    }

    var canSave: Bool {
        selectedLocation != nil
    }

    func resolveInitialLocationIfNeeded() {
            guard let selectedLocation else {
                return
            }

            resolveLocationIfNeeded(for: selectedLocation)
        }

    func restoreCapturedLocation() {
            guard let originalLocation = originalClipLocation.location else {
                return
            }

            applyLocation(originalLocation)
        }

    // 새 좌표를 선택
    func selectLocation(
        latitude: Double,
        longitude: Double
    ) {
        let location = LogLocationDraft(
            latitude: latitude,
            longitude: longitude
        )

        applyLocation(location)
    }

    func retryLocationResolution() {
            guard let selectedLocation else {
                return
            }

            resolveLocationIfNeeded(for: selectedLocation)
        }

    func cancelLocationResolution() {
            locationResolutionTask?.cancel()
            locationResolutionTask = nil
            isResolvingLocation = false
        }

    func makeUpdatedClipLocation() -> LogComposeClipLocationDraft {
        var updatedClipLocation = originalClipLocation
        updatedClipLocation.location = selectedLocation

        return updatedClipLocation
    }

    private func applyLocation(_ location: LogLocationDraft) {
            selectedLocation = location
            locationResolutionError = nil

            resolveLocationIfNeeded(for: location)
        }

    private func resolveLocationIfNeeded(
            for location: LogLocationDraft
        ) {
            guard location.address == nil else {
                locationResolutionTask?.cancel()
                locationResolutionTask = nil
                isResolvingLocation = false
                return
            }

            locationResolutionTask?.cancel()
            isResolvingLocation = true
            locationResolutionError = nil

            locationResolutionTask = Task { [weak self] in
                do {
                    try await Task.sleep(
                        nanoseconds: 350_000_000
                    )

                    guard !Task.isCancelled else {
                        return
                    }

                    await self?.resolveLocation(for: location)
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }
        }

    private func resolveLocation(
            for location: LogLocationDraft
        ) async {
            do {
                let resolvedLocation =
                    try await logLocationRepository.resolveLocation(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )

                guard
                    !Task.isCancelled,
                    isCurrentSelection(location)
                else {
                    return
                }

                selectedLocation = LogLocationDraft(
                    latitude: resolvedLocation.latitude,
                    longitude: resolvedLocation.longitude,
                    name: resolvedLocation.name,
                    address: resolvedLocation.address
                )

                isResolvingLocation = false
            } catch is CancellationError {
                return
            } catch {
                guard
                    !Task.isCancelled,
                    isCurrentSelection(location)
                else {
                    return
                }

                isResolvingLocation = false
                locationResolutionError =
                    ClipLocationEditErrorPolicy.presentation(
                        for: error
                    )
            }
        }

    private func isCurrentSelection(
            _ location: LogLocationDraft
        ) -> Bool {
            selectedLocation?.latitude == location.latitude &&
            selectedLocation?.longitude == location.longitude
        }

    private func timelineTimeText(
        _ seconds: TimeInterval
    ) -> String {
        let totalSeconds = Int(seconds.rounded(.down))

        return String(
            format: "%02d:%02d",
            totalSeconds / 60,
            totalSeconds % 60
        )
    }
}
