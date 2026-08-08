//
//  ClipLocationTimestampOverlayFactory.swift
//  Maplog
//
//  위치·시간 템플릿을 실제 자막 묶음으로 바꾸는 순수 변환기
//

import Foundation

enum ClipLocationTimestampOverlayFactory {
    static func makeOverlays(
        for clip: CaptureDraftClip,
        template: ClipLocationTimestampTemplate,
        groupID: UUID = UUID()
    ) -> [ClipTextOverlay] {
        guard let duration = clip.duration, duration > 0 else {
            return []
        }

        let placeName = resolvedPlaceName(from: clip)
        let date = formattedCapturedAt(
            clip.capturedAt,
            format: "yyyy.MM.dd"
        )
        let time = formattedCapturedAt(
            clip.capturedAt,
            format: "HH:mm"
        )

        switch template {
        case .vlogLine:
            return [
                overlay(
                    clip: clip,
                    text: time,
                    template: template,
                    groupID: groupID,
                    duration: duration,
                    position: ClipOverlayPosition(x: 0.025, y: 0.52),
                    alignment: .leading,
                    style: ClipTextStyle(
                        font: .standard,
                        weight: .medium,
                        color: .white,
                        fontSize: 10
                    )
                ),
                overlay(
                    clip: clip,
                    text: "📍 " + placeName,
                    template: template,
                    groupID: groupID,
                    duration: duration,
                    position: ClipOverlayPosition(x: 0.975, y: 0.52),
                    alignment: .trailing,
                    style: ClipTextStyle(
                        font: .standard,
                        weight: .medium,
                        color: .white,
                        fontSize: 10
                    )
                ),
                overlay(
                    clip: clip,
                    text: "mini vlog",
                    template: template,
                    groupID: groupID,
                    duration: duration,
                    position: ClipOverlayPosition(x: 0.50, y: 0.52),
                    alignment: .center,
                    style: ClipTextStyle(
                        font: .rounded,
                        weight: .semibold,
                        color: .white,
                        fontSize: 10
                    )
                )
            ]

        case .filmCorner:
            return [
                overlay(
                    clip: clip,
                    text: "●  " + date + "  " + time + "\n" + placeName.uppercased(),
                    template: template,
                    groupID: groupID,
                    duration: duration,
                    position: ClipOverlayPosition(x: 0.04, y: 0.93),
                    alignment: .leading,
                    style: ClipTextStyle(
                        font: .monospaced,
                        weight: .medium,
                        color: .white,
                        fontSize: 11
                    )
                )
            ]

        case .lowerThird:
            return [
                overlay(
                    clip: clip,
                    text: placeName,
                    template: template,
                    groupID: groupID,
                    duration: duration,
                    position: ClipOverlayPosition(x: 0.04, y: 0.87),
                    alignment: .leading,
                    style: ClipTextStyle(
                        font: .standard,
                        weight: .semibold,
                        color: .white,
                        fontSize: 18
                    )
                ),
                overlay(
                    clip: clip,
                    text: date + " · " + time,
                    template: template,
                    groupID: groupID,
                    duration: duration,
                    position: ClipOverlayPosition(x: 0.04, y: 0.93),
                    alignment: .leading,
                    style: ClipTextStyle(
                        font: .standard,
                        weight: .medium,
                        color: .white,
                        fontSize: 11
                    )
                )
            ]

        case .glassCard:
            return [
                overlay(
                    clip: clip,
                    text: "📍\n" + placeName + "\n" + date + " · " + time,
                    template: template,
                    groupID: groupID,
                    duration: duration,
                    position: ClipOverlayPosition(x: 0.96, y: 0.92),
                    alignment: .trailing,
                    style: ClipTextStyle(
                        font: .standard,
                        weight: .semibold,
                        color: .white,
                        fontSize: 14,
                        containerStyle: .glass
                    )
                )
            ]
        }
    }

    private static func overlay(
        clip: CaptureDraftClip,
        text: String,
        template: ClipLocationTimestampTemplate,
        groupID: UUID,
        duration: TimeInterval,
        position: ClipOverlayPosition,
        alignment: ClipTextAlignment,
        style: ClipTextStyle
    ) -> ClipTextOverlay {
        ClipTextOverlay(
            clipID: clip.id,
            text: text,
            kind: .locationTimestamp(template: template),
            startTime: 0,
            endTime: duration,
            position: position,
            style: style,
            alignment: alignment,
            locationTimestampGroupID: groupID
        )
    }

    private static func resolvedPlaceName(
        from clip: CaptureDraftClip
    ) -> String {
        guard let placeName = clip.location?.placeName else {
            return "기록한 장소"
        }

        let trimmedName = placeName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmedName.isEmpty ? "기록한 장소" : trimmedName
    }

    private static func formattedCapturedAt(
        _ date: Date,
        format: String
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = format

        return formatter.string(from: date)
    }
}
