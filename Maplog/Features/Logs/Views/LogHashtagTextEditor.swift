//
//  LogHashtagTextEditor.swift
//  Maplog
//
//  작성 중인 본문 안에서 해시태그만 구분해 보여 주는 입력 컴포넌트입니다.
//

import SwiftUI
import UIKit

/// SwiftUI `TextEditor`는 부분 문자열별 글자색을 지원하지 않으므로,
/// 실제 입력은 `UITextView`가 맡고 ViewModel에는 순수한 String만 전달합니다.
struct LogHashtagTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(
        context: Context
    ) -> UITextView {
        let textView = UITextView()

        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.adjustsFontForContentSizeCategory = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(
            top: MaplogSpacing.medium,
            left: MaplogSpacing.medium,
            bottom: MaplogSpacing.medium,
            right: MaplogSpacing.medium
        )
        textView.textContainer.lineFragmentPadding = 0
        textView.accessibilityLabel = "피드 내용"
        textView.accessibilityHint = "본문에 해시태그를 입력하면 태그가 강조되고 통합 검색 키워드로 저장됩니다"

        context.coordinator.applyHashtagStyle(to: textView)

        return textView
    }

    func updateUIView(
        _ textView: UITextView,
        context: Context
    ) {
        context.coordinator.parent = self

        if textView.text != text {
            context.coordinator.applyHashtagStyle(
                to: textView,
                text: text
            )
        }

        if isFocused, !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !isFocused, textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: LogHashtagTextEditor
        private var isApplyingStyle = false

        init(
            parent: LogHashtagTextEditor
        ) {
            self.parent = parent
        }

        func textViewDidBeginEditing(
            _ textView: UITextView
        ) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(
            _ textView: UITextView
        ) {
            parent.isFocused = false
        }

        func textViewDidChange(
            _ textView: UITextView
        ) {
            guard !isApplyingStyle else {
                return
            }

            if parent.text != textView.text {
                parent.text = textView.text
            }

            applyHashtagStyle(to: textView)
        }

        func applyHashtagStyle(
            to textView: UITextView,
            text: String? = nil
        ) {
            let displayedText = text ?? textView.text ?? ""
            let selectedRange = textView.selectedRange
            let baseFont = UIFont.preferredFont(forTextStyle: .body)
            let tagFont = UIFont.systemFont(
                ofSize: baseFont.pointSize,
                weight: .semibold
            )
            let attributedText = NSMutableAttributedString(
                string: displayedText,
                attributes: [
                    .font: baseFont,
                    .foregroundColor: UIColor(Color.maplogInk)
                ]
            )

            for range in LogCustomTagParser.hashtagRanges(in: displayedText) {
                attributedText.addAttributes(
                    [
                        .font: tagFont,
                        .foregroundColor: UIColor(Color.maplogPrimary)
                    ],
                    range: range
                )
            }

            isApplyingStyle = true
            textView.attributedText = attributedText
            textView.typingAttributes = [
                .font: baseFont,
                .foregroundColor: UIColor(Color.maplogInk)
            ]
            textView.selectedRange = safeSelection(
                selectedRange,
                textLength: attributedText.length
            )
            isApplyingStyle = false
        }

        private func safeSelection(
            _ selection: NSRange,
            textLength: Int
        ) -> NSRange {
            guard selection.location != NSNotFound else {
                return NSRange(location: textLength, length: 0)
            }

            let location = min(selection.location, textLength)
            let length = min(selection.length, textLength - location)

            return NSRange(location: location, length: length)
        }
    }
}
