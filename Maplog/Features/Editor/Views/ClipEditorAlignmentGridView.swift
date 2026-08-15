//
//  ClipEditorAlignmentGridView.swift
//  Maplog
//
//  Created by 한채림 on 8/7/26.
// 텍스트 이동 중에만 정렬 격자 보이기

import SwiftUI

struct ClipEditorAlignmentGridView: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let horizontalSafeInset =
                width * CGFloat(
                    ClipTextOverlaySafeArea.horizontalInset
                )
            let verticalSafeInset =
                height * CGFloat(
                    ClipTextOverlaySafeArea.verticalInset
                )

            ZStack {
                Path { path in
                    path.move(
                        to: CGPoint(x: horizontalSafeInset, y: 0)
                    )
                    path.addLine(
                        to: CGPoint(
                            x: horizontalSafeInset,
                            y: height
                        )
                    )

                    path.move(
                        to: CGPoint(
                            x: width - horizontalSafeInset,
                            y: 0
                        )
                    )
                    path.addLine(
                        to: CGPoint(
                            x: width - horizontalSafeInset,
                            y: height
                        )
                    )

                    path.move(
                        to: CGPoint(x: 0, y: verticalSafeInset)
                    )
                    path.addLine(
                        to: CGPoint(
                            x: width,
                            y: verticalSafeInset
                        )
                    )

                    path.move(
                        to: CGPoint(
                            x: 0,
                            y: height - verticalSafeInset
                        )
                    )
                    path.addLine(
                        to: CGPoint(
                            x: width,
                            y: height - verticalSafeInset
                        )
                    )
                }
                .stroke(
                    .cyan.opacity(0.62),
                    style: StrokeStyle(
                        lineWidth: 1,
                        dash: [5, 4]
                    )
                )

                Path { path in
                    path.move(
                        to: CGPoint(x: width / 3, y: 0)
                    )
                    path.addLine(
                        to: CGPoint(x: width / 3, y: height)
                    )

                    path.move(
                        to: CGPoint(x: width * 2 / 3, y: 0)
                    )
                    path.addLine(
                        to: CGPoint(x: width * 2 / 3, y: height)
                    )

                    path.move(
                        to: CGPoint(x: 0, y: height / 3)
                    )
                    path.addLine(
                        to: CGPoint(x: width, y: height / 3)
                    )

                    path.move(
                        to: CGPoint(x: 0, y: height * 2 / 3)
                    )
                    path.addLine(
                        to: CGPoint(x: width, y: height * 2 / 3)
                    )
                }
                .stroke(
                    .white.opacity(0.38),
                    style: StrokeStyle(
                        lineWidth: 1,
                        dash: [4, 4]
                    )
                )

                Path { path in
                    path.move(
                        to: CGPoint(x: width / 2, y: 0)
                    )
                    path.addLine(
                        to: CGPoint(x: width / 2, y: height)
                    )

                    path.move(
                        to: CGPoint(x: 0, y: height / 2)
                    )
                    path.addLine(
                        to: CGPoint(x: width, y: height / 2)
                    )
                }
                .stroke(
                    Color.white.opacity(0.28),
                    style: StrokeStyle(
                        lineWidth: 1,
                        dash: [5, 4]
                    )
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
