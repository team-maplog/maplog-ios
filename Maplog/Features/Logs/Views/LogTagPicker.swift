//
//  LogTagPicker.swift
//  Maplog
//

import SwiftUI

/// 로그 발행과 수정 화면에서 같은 태그 선택 경험을 사용합니다.
struct LogTagPicker: View {
    let selectedTags: Set<LogTag>
    let onToggle: (LogTag) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 88), spacing: MaplogSpacing.xSmall)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: MaplogSpacing.xSmall) {
            ForEach(LogTag.allCases) { tag in
                let isSelected = selectedTags.contains(tag)

                Button {
                    onToggle(tag)
                } label: {
                    Text(tag.title)
                        .font(MaplogFont.caption)
                        .foregroundStyle(
                            isSelected ? Color.maplogInk : Color.maplogMuted
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: MaplogSize.compactControlHeight)
                        .background(
                            isSelected
                            ? Color.maplogLime
                            : Color.maplogSurface,
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(
                                    isSelected
                                    ? Color.maplogLime
                                    : Color.maplogLine,
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(MaplogPressFeedbackStyle())
                .accessibilityLabel("\(tag.title) 태그")
                .accessibilityValue(isSelected ? "선택됨" : "선택되지 않음")
            }
        }
    }
}
