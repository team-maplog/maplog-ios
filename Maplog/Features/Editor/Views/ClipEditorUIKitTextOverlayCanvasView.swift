//
//  ClipEditorUIKitTextOverlayCanvasView.swift
//  Maplog
//
//  Created by 한채림 on 8/5/26.
// SwiftUI와 UIKit을 연결하는 어댑터, UIViewRepresentable을 쓰면 SwiftUI 화면 안에 UIKit UIView를 넣을 수 있음
//

import SwiftUI
import UIKit

struct ClipEditorUIKitTextOverlayCanvasView: UIViewRepresentable {
    let items: [ClipTextOverlayItemViewData]
    let selectedID: UUID?

    let onSelect: (UUID) -> Void
    let onPositionChange: (
        UUID,
        ClipOverlayPosition
    ) -> Void
    let onDragChanged: (Bool) -> Void
    let onDelete: (UUID) -> Void
    let textInputRequestID: UUID?
    let onTextInputRequestHandled: (UUID) -> Void
    let onTextChange: (UUID, String) -> Void
    let onTextEditingFinished: (UUID) -> Void
    let onBackgroundTap: () -> Void // 빈 영역 탭 콜백
    let onTextEditingStarted: (UUID) -> Void
    let onTemplateSwipe: (Int) -> Void


    // 화면에 처음 나타날 때 UIKit 캔버스 객체를 딱 한 번 만듦
    func makeUIView(context: Context) -> EditorTextOverlayCanvasUIView {
        EditorTextOverlayCanvasUIView()
    }

    // ViewModel에서 자막 데이터가 바뀌었을 때, 이미 만들어 둔 캔버스에 최신 데이터를 전달
    func updateUIView(
        _ uiView: EditorTextOverlayCanvasUIView,
        context: Context
    ) {
        uiView.update(
            items: items,
            selectedID: selectedID,
            onSelect: onSelect,
            onPositionChange: onPositionChange,
            onDragChanged: onDragChanged,
            onDelete: onDelete,
            textInputRequestID: textInputRequestID,
            onTextInputRequestHandled: onTextInputRequestHandled,
            onTextChange: onTextChange,
            onTextEditingFinished: onTextEditingFinished,
            onBackgroundTap: onBackgroundTap,
            onTextEditingStarted: onTextEditingStarted,
            onTemplateSwipe: onTemplateSwipe
        )
    }
}
// 스냅용 타입과 상태 추가
private enum TextOverlaySnapAnchor: Equatable {
    case start // 왼쪽, 세로 기준 위
    case center // 중앙, 중앙
    case end // 오른쪽, 아래
}

private struct TextOverlaySnapState: Equatable {
    let x: TextOverlaySnapAnchor?
    let y: TextOverlaySnapAnchor?

    static let none = TextOverlaySnapState(
        x: nil,
        y: nil
    )

    var isActive: Bool {
        x != nil || y != nil
    }
}

private struct TextOverlaySnapCandidate {
    let anchor: TextOverlaySnapAnchor
    let center: CGFloat
    let guideCoordinate: CGFloat
}

// 실제 UIKit 캔버스, 자막별 UILabel, 삭제 버튼, UIPanGestureRecognizer를 넣음
final class EditorTextOverlayCanvasUIView: UIView, UIGestureRecognizerDelegate {
    private var itemViews: [
            UUID: EditorTextOverlayItemUIView
        ] = [:]

        private var onSelect: ((UUID) -> Void)?
        private var onPositionChange: ((
            UUID,
            ClipOverlayPosition
        ) -> Void)?
        private var onDragChanged: ((Bool) -> Void)?
        private var onDelete: ((UUID) -> Void)?
        private var textInputRequestID: UUID?
        private var onTextInputRequestHandled: ((UUID) -> Void)?
        private var onTextChange: ((UUID, String) -> Void)?
        private var onTextEditingFinished: ((UUID) -> Void)?
        private var isFulfillingTextInputRequest = false
        private let backgroundTapGesture = UITapGestureRecognizer()
        private var onBackgroundTap: (() -> Void)?
        private var onTextEditingStarted: ((UUID) -> Void)?
        private var onLocationTimestampTemplateSwipe:
        ((UUID, Int) -> Void)?
        private let templateSwipeGesture = UIPanGestureRecognizer()
        private var onTemplateSwipe: ((Int) -> Void)?
        private let activeGuideView = EditorTextOverlayActiveGuideUIView()
        private let snapFeedback = UISelectionFeedbackGenerator()
        private var activeSnapState = TextOverlaySnapState.none
        private let snapThreshold: CGFloat = 12
        private let snapInset: CGFloat = 18

        override init(frame: CGRect) {
            super.init(frame: frame)

            backgroundColor = .clear

            activeGuideView.translatesAutoresizingMaskIntoConstraints = false
            activeGuideView.isUserInteractionEnabled = false

            insertSubview(activeGuideView, at: 0)

            NSLayoutConstraint.activate([
                activeGuideView.topAnchor.constraint(equalTo: topAnchor),
                activeGuideView.leadingAnchor.constraint(equalTo: leadingAnchor),
                activeGuideView.trailingAnchor.constraint(equalTo: trailingAnchor),
                activeGuideView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])

            isUserInteractionEnabled = true

            backgroundTapGesture.addTarget(
                    self,
                    action: #selector(handleBackgroundTap)
                )

                backgroundTapGesture.delegate = self
                backgroundTapGesture.cancelsTouchesInView = false

                addGestureRecognizer(backgroundTapGesture)

            templateSwipeGesture.addTarget(
                self,
                action: #selector(handleTemplateSwipe(_:))
            )

            templateSwipeGesture.delegate = self
            templateSwipeGesture.cancelsTouchesInView = false

            backgroundTapGesture.require(
                toFail: templateSwipeGesture
            )

            addGestureRecognizer(templateSwipeGesture)
        }


        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    func update(
        items: [ClipTextOverlayItemViewData],
        selectedID: UUID?,
        onSelect: @escaping (UUID) -> Void,
        onPositionChange: @escaping (
            UUID,
            ClipOverlayPosition
        ) -> Void,
        onDragChanged: @escaping (Bool) -> Void,
        onDelete: @escaping (UUID) -> Void,
        textInputRequestID: UUID?,
        onTextInputRequestHandled: @escaping (UUID) -> Void,
        onTextChange: @escaping (UUID, String) -> Void,
        onTextEditingFinished: @escaping (UUID) -> Void,
        onBackgroundTap: @escaping () -> Void,
        onTextEditingStarted: @escaping (UUID) -> Void,
        onTemplateSwipe: @escaping (Int) -> Void
    ) {
        self.onSelect = onSelect
        self.onPositionChange = onPositionChange
        self.onDragChanged = onDragChanged
        self.onDelete = onDelete
        self.textInputRequestID = textInputRequestID
        self.onTextInputRequestHandled = onTextInputRequestHandled
        self.onTextChange = onTextChange
        self.onTextEditingFinished = onTextEditingFinished
        self.onBackgroundTap = onBackgroundTap
        self.onTextEditingStarted = onTextEditingStarted
        self.onTemplateSwipe = onTemplateSwipe

        let incomingIDs = Set(items.map(\.id))

                let removedIDs = itemViews.keys.filter { id in
                    !incomingIDs.contains(id)
                }

                for id in removedIDs {
                    itemViews[id]?.removeFromSuperview()
                    itemViews[id] = nil
                }

                for item in items {
                    let itemView: EditorTextOverlayItemUIView

                    if let existingView = itemViews[item.id] {
                        itemView = existingView
                    } else {
                        itemView = EditorTextOverlayItemUIView()
                        itemViews[item.id] = itemView
                        addSubview(itemView)
                    }

                    itemView.configure(
                        item: item,
                        isSelected: item.id == selectedID
                    )

                    itemView.onTap = { [weak self] id in
                        self?.onSelect?(id)
                    }

                    itemView.onDragChanged = { [weak self] isDragging in
                        self?.onDragChanged?(isDragging)
                    }

                    itemView.onDelete = { [weak self] id in
                        self?.onDelete?(id)
                    }

                    itemView.onDragEnded = { [weak self] id, center in
                        guard let self else {
                            return
                        }

                        self.onPositionChange?(
                            id,
                            self.normalizedPosition(for: center)
                        )
                    }

                    itemView.onTextChange = { [weak self] id, text in
                        self?.onTextChange?(id, text)
                    }

                    itemView.onTextEditingFinished = { [weak self] id in
                        self?.onTextEditingFinished?(id)
                    }

                    itemView.onTextEditingStarted = { [weak self] id in
                        self?.onTextEditingStarted?(id)
                    }

                    itemView.onDragChanged = { [weak self] isDragging in
                        guard let self else {
                            return
                        }

                        if isDragging {
                            self.beginSnapInteraction()
                        } else {
                            self.endSnapInteraction()
                        }

                        self.onDragChanged?(isDragging)
                    }

                    itemView.onDragMoved = { [weak self, weak itemView] proposedCenter in
                        guard
                            let self,
                            let itemView
                        else {
                            return proposedCenter
                        }

                        return self.snappedCenter(
                            for: proposedCenter,
                            itemSize: itemView.bounds.size
                        )
                    }

                }

                setNeedsLayout()
    }

    // 요청을 실제 UITextView에 전달하는 함수
    private func fulfillTextInputRequestIfNeeded() {
        guard
            let textInputRequestID,
            !isFulfillingTextInputRequest,
            let itemView = itemViews[textInputRequestID],
            itemView.window != nil // 아직 화면에 붙지 않은 UIKit View에는 키보드를 열지 않는다
        else {
            return
        }

        isFulfillingTextInputRequest = true

        let didBeginEditing = itemView.beginTextEditing(
            shouldSelectAll: true
        )

        isFulfillingTextInputRequest = false

        guard didBeginEditing else {
            return
        }

        self.textInputRequestID = nil
        onTextInputRequestHandled?(textInputRequestID)
    }

    override func layoutSubviews() {
            super.layoutSubviews()

            for itemView in itemViews.values {
                itemView.place(in: bounds.size)
            }

            fulfillTextInputRequestIfNeeded()
        }

    private func normalizedPosition(
        for center: CGPoint
    ) -> ClipOverlayPosition {
        guard bounds.width > 0, bounds.height > 0 else {
            return .center
        }

        return ClipOverlayPosition(
            x: Double(center.x / bounds.width),
            y: Double(center.y / bounds.height)
        )
    }

    private func snappedCenter(
        for proposedCenter: CGPoint,
        itemSize: CGSize
    ) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else {
            return proposedCenter
        }

        let halfWidth = itemSize.width / 2
        let halfHeight = itemSize.height / 2

        let clampedX = min(
            max(proposedCenter.x, halfWidth),
            bounds.width - halfWidth
        )

        let clampedY = min(
            max(proposedCenter.y, halfHeight),
            bounds.height - halfHeight
        )

        let horizontalCandidates = [
            TextOverlaySnapCandidate(
                anchor: .start,
                center: halfWidth + snapInset,
                guideCoordinate: snapInset
            ),
            TextOverlaySnapCandidate(
                anchor: .center,
                center: bounds.midX,
                guideCoordinate: bounds.midX
            ),
            TextOverlaySnapCandidate(
                anchor: .end,
                center: bounds.width - halfWidth - snapInset,
                guideCoordinate: bounds.width - snapInset
            )
        ]

        let verticalCandidates = [
            TextOverlaySnapCandidate(
                anchor: .start,
                center: halfHeight + snapInset,
                guideCoordinate: snapInset
            ),
            TextOverlaySnapCandidate(
                anchor: .center,
                center: bounds.midY,
                guideCoordinate: bounds.midY
            ),
            TextOverlaySnapCandidate(
                anchor: .end,
                center: bounds.height - halfHeight - snapInset,
                guideCoordinate: bounds.height - snapInset
            )
        ]

        let horizontalSnap = closestSnap(
            to: clampedX,
            candidates: horizontalCandidates
        )

        let verticalSnap = closestSnap(
            to: clampedY,
            candidates: verticalCandidates
        )

        let snappedCenter = CGPoint(
            x: horizontalSnap?.center ?? clampedX,
            y: verticalSnap?.center ?? clampedY
        )

        let newSnapState = TextOverlaySnapState(
            x: horizontalSnap?.anchor,
            y: verticalSnap?.anchor
        )

        updateSnapFeedback(for: newSnapState)

        activeGuideView.show(
            verticalX: horizontalSnap?.guideCoordinate,
            horizontalY: verticalSnap?.guideCoordinate
        )

        return snappedCenter
    }

    private func closestSnap(
        to value: CGFloat,
        candidates: [TextOverlaySnapCandidate]
    ) -> TextOverlaySnapCandidate? {
        guard let closest = candidates.min(
            by: {
                abs(value - $0.center) < abs(value - $1.center)
            }
        ) else {
            return nil
        }

        guard abs(value - closest.center) <= snapThreshold else {
            return nil
        }

        return closest
    }

    private func updateSnapFeedback(
        for newSnapState: TextOverlaySnapState
    ) {
        guard activeSnapState != newSnapState else {
            return
        }

        activeSnapState = newSnapState

        guard newSnapState.isActive else {
            return
        }

        snapFeedback.selectionChanged()
        snapFeedback.prepare()
    }

    private func beginSnapInteraction() {
        activeSnapState = .none
        snapFeedback.prepare()
        activeGuideView.hide()
    }

    private func endSnapInteraction() {
        activeSnapState = .none
        activeGuideView.hide()
    }

    @objc // 배경만 감지하는 제스처 처리
    private func handleBackgroundTap() {
        endEditing(true)
        onBackgroundTap?()
    }

    @objc
    private func handleTemplateSwipe(
        _ recognizer: UIPanGestureRecognizer
    ) {
        guard recognizer.state == .ended else {
            return
        }

        let translation = recognizer.translation(in: self)
        let velocity = recognizer.velocity(in: self)

        let isMostlyHorizontal =
            abs(translation.x) > abs(translation.y) * 1.5

        let movedEnough = abs(translation.x) >= 44
        let isFastEnough = abs(velocity.x) >= 400

        guard
            isMostlyHorizontal,
            movedEnough,
            isFastEnough
        else {
            return
        }

        let offset = translation.x < 0 ? 1 : -1

        onTemplateSwipe?(offset)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        var currentView = touch.view

        while let view = currentView {
            if view is EditorTextOverlayItemUIView {
                return false
            }

            currentView = view.superview
        }

        return true
    }
}

final class EditorTextOverlayItemUIView: UIView, UIGestureRecognizerDelegate, UITextViewDelegate {
    var onTap: ((UUID) -> Void)?
    var onDragChanged: ((Bool) -> Void)?
    var onDragEnded: ((UUID, CGPoint) -> Void)?
    var onDelete: ((UUID) -> Void)?
    var onTextChange: ((UUID, String) -> Void)?
    var onTextEditingFinished: ((UUID) -> Void)?
    var onTextEditingStarted: ((UUID) -> Void)?
    var onDragMoved: ((CGPoint) -> CGPoint)?

    private let panGesture = UIPanGestureRecognizer()
    private let tapGesture = UITapGestureRecognizer()
    private let selectionBorderView = UIView()
    private let deleteButton = UIButton(type: .system)

    private var itemID: UUID?
    private var position: ClipOverlayPosition = .center
    private var alignment: ClipTextAlignment = .center
    private var startCenter = CGPoint.zero
    private var isPanning = false
    private let textView = UITextView()

    override init(frame: CGRect) {
        super.init(frame: frame)

  // UITextView 설정
        textView.delegate = self
        textView.backgroundColor = .clear
        textView.textAlignment = .center
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.maximumNumberOfLines = 3
        textView.keyboardAppearance = .dark
        textView.accessibilityLabel = "영상 위 텍스트"

        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: 6
            ),
            textView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 8
            ),
            textView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -8
            ),
            textView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -6
            )
        ])
        // 텍스트를 잡고 움직일 땐, UITextView의 내부 제스처보다 우리 자막 이동 제스처를 우선한다
        textView.panGestureRecognizer.require(
            toFail: panGesture
        )

        isUserInteractionEnabled = true

        // 테두리 뷰 설정
        selectionBorderView.isUserInteractionEnabled = false
        selectionBorderView.layer.cornerRadius = 8
        selectionBorderView.layer.borderWidth = 2
        selectionBorderView.layer.borderColor =
            UIColor(Color.maplogLime).cgColor

        selectionBorderView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(selectionBorderView)

        NSLayoutConstraint.activate([
            selectionBorderView.topAnchor.constraint(
                equalTo: topAnchor
            ),
            selectionBorderView.leadingAnchor.constraint(
                equalTo: leadingAnchor
            ),
            selectionBorderView.trailingAnchor.constraint(
                equalTo: trailingAnchor
            ),
            selectionBorderView.bottomAnchor.constraint(
                equalTo: bottomAnchor
            )
        ])

        // 삭제 버튼 설정
        clipsToBounds = false

        deleteButton.setImage(
            UIImage(
                systemName: "xmark",
                withConfiguration: UIImage.SymbolConfiguration(
                    pointSize: 10,
                    weight: .bold
                )
            ),
            for: .normal
        )

        deleteButton.tintColor = .white
        deleteButton.backgroundColor = UIColor(
            Color.maplogInk
        )

        deleteButton.layer.cornerRadius = 9
        deleteButton.clipsToBounds = true
        deleteButton.isHidden = true
        deleteButton.accessibilityLabel = "텍스트 삭제"

        deleteButton.translatesAutoresizingMaskIntoConstraints = false

        deleteButton.addTarget(
            self,
            action: #selector(handleDelete),
            for: .touchUpInside
        )

        addSubview(deleteButton)

        NSLayoutConstraint.activate([
            deleteButton.widthAnchor.constraint(
                equalToConstant: 18
            ),
            deleteButton.heightAnchor.constraint(
                equalToConstant: 18
            ),
            deleteButton.centerXAnchor.constraint(
                equalTo: trailingAnchor
            ),
            deleteButton.centerYAnchor.constraint(
                equalTo: topAnchor
            )
        ])

        panGesture.delegate = self
        tapGesture.delegate = self

        panGesture.addTarget(
            self,
            action: #selector(handlePan(_:))
        )

        tapGesture.addTarget(
            self,
            action: #selector(handleTap)
        )

        // 탭과 드래그가 겹치지 않게 하는 코드
        tapGesture.require(toFail: panGesture)

        addGestureRecognizer(panGesture)
        addGestureRecognizer(tapGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // 자막 아이템 뷰에 입력 시작 함수
    @discardableResult // @discardableResult는 이 함수가 Bool을 반환하지만, 필요하지 않은 상황에는 반환값을 무시해도 경고를 내지말라는 것
    func beginTextEditing(
        shouldSelectAll: Bool
    ) -> Bool {
        guard textView.becomeFirstResponder() else { // becomeFirstResponder()는 UIKit에서 이 UITextView가 지금 키보드 입력을 받을 주인공이다라고 지정하는 함수
            return false
        }

        if shouldSelectAll {
            DispatchQueue.main.async { [weak self] in
                self?.textView.selectAll(nil)
            }
        }

        return true
    }


    func configure( // 화면 갱신
        item: ClipTextOverlayItemViewData,
        isSelected: Bool
    ) {
        itemID = item.id
        position = item.position
        alignment = item.alignment

        // 사용자가 한 글자를 입력할 때마다 ViewModel도 갱신되지만, 이미 같은 내용이라면 UITextView.text를 다시 넣지 않음. 그래서 커서·한글 조합·입력 흐름이 불필요하게 초기화되지 않음
        if textView.text != item.text {
            textView.text = item.text
        }

        textView.font = makeFont(style: item.style)
        textView.textColor = makeTextColor(style: item.style)
        textView.textAlignment = makeTextAlignment(
            for: item.alignment
        )
        applyContainerStyle(item.style.containerStyle)

        selectionBorderView.isHidden = !isSelected
        deleteButton.isHidden = !isSelected
        deleteButton.layer.zPosition = 1

        deleteButton.isHidden = !isSelected // 선택되지 않은 텍스트에는 x 버튼이 없고, 텍스트를 탭해 선택되면 x가 나타남
        bringSubviewToFront(deleteButton)
    }

    func place(in canvasSize: CGSize) { // 텍스트의 크기와 캔버스 안 위치 계산
        guard
            !isPanning,
            canvasSize.width > 0,
            canvasSize.height > 0
        else {
            return
        }

        let maximumWidth = canvasSize.width * 0.75

        let textSize = textView.sizeThatFits(
            CGSize(
                width: maximumWidth - 16,
                height: .greatestFiniteMagnitude
            )
        )

        bounds.size = CGSize(
            width: max(44, ceil(textSize.width) + 16),
            height: max(44, ceil(textSize.height) + 12)
        )

        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        let anchoredX = CGFloat(position.x) * canvasSize.width

        let intendedCenterX: CGFloat

        switch alignment {
        case .leading:
            intendedCenterX = anchoredX + halfWidth
        case .center:
            intendedCenterX = anchoredX
        case .trailing:
            intendedCenterX = anchoredX - halfWidth
        }

        center = CGPoint(
            x: min(
                max(intendedCenterX, halfWidth),
                canvasSize.width - halfWidth
            ),
            y: min(
                max(
                    CGFloat(position.y) * canvasSize.height,
                    halfHeight
                ),
                canvasSize.height - halfHeight
            )
        )
    }

    @objc
    private func handleTap() {
        guard let itemID else {
            return
        }

        onTap?(itemID)
    }

    @objc // 삭제 함수와 버튼 터치 분리
    private func handleDelete() {
        guard let itemID else {
            return
        }

        onDelete?(itemID)
    }

    @objc // 텍스트를 드래그해서 움직이는 함수
//    canvas (부모 뷰, superview)
//     └─ 텍스트 UILabel (현재 self)
    private func handlePan(
        _ recognizer: UIPanGestureRecognizer
    ) {
        guard let canvas = superview else {
            return
        }

        switch recognizer.state {
        case .began: // 드래그 시작
            guard let itemID else {
                return
            }

            textView.resignFirstResponder() // 드래그를 시작하면 편집을 잠시 끝내고 키보드가 닫힘
            isPanning = true // 지금 드래그 중이라고 기록
            startCenter = center // 드래그를 시작한 당시 텍스트의 중심 위치 저장

            onTap?(itemID) // 드래그를 시작해도 해당 텍스트는 선택 상태가 되어야 하므로 호출
            onDragChanged?(true)

            canvas.bringSubviewToFront(self)

        case .changed:
            let translation = recognizer.translation(in: canvas)

            let proposedCenter = CGPoint(
                x: startCenter.x + translation.x,
                y: startCenter.y + translation.y
            )

            center = onDragMoved?(proposedCenter) ?? proposedCenter


//            드래그 중 상태 해제
//            최종 중심 위치(center)를 바깥쪽에 전달
//            바깥쪽 ViewModel이나 상태가 이 위치를 저장할 수 있음
//            “드래그 끝” 알림 전달
        case .ended:
                guard let itemID else {
                    return
                }

                isPanning = false
                onDragEnded?(itemID, center)
                onDragChanged?(false)

            case .cancelled, .failed:
                isPanning = false
                center = startCenter
                onDragChanged?(false)

            default:
                break
            }
        }
    // UITextView 입력 이벤트
    func textViewDidBeginEditing(
        _ textView: UITextView
    ) {
        guard let itemID else {
            return
        }

        onTap?(itemID)
        onTextEditingStarted?(itemID)
    }

    func textViewDidChange(
        _ textView: UITextView
    ) {
        guard let itemID else {
            return
        }

        onTextChange?(itemID, textView.text)
    }

    func textViewDidEndEditing(
        _ textView: UITextView
    ) {
        guard let itemID else {
            return
        }

        onTextEditingFinished?(itemID)
    }


    private func makeFont(
        style: ClipTextStyle
    ) -> UIFont {
        let baseFont = UIFont.systemFont(
            ofSize: style.fontSize,
            weight: fontWeight(for: style.weight)
        )

        let descriptor: UIFontDescriptor

        switch style.font {
        case .standard:
            descriptor = baseFont.fontDescriptor

        case .rounded:
            descriptor = baseFont.fontDescriptor.withDesign(.rounded)
                ?? baseFont.fontDescriptor

        case .serif:
            descriptor = baseFont.fontDescriptor.withDesign(.serif)
                ?? baseFont.fontDescriptor

        case .monospaced:
            descriptor = baseFont.fontDescriptor.withDesign(.monospaced)
                ?? baseFont.fontDescriptor
        }

        return UIFont(
            descriptor: descriptor,
            size: baseFont.pointSize
        )
    }

    private func fontWeight(
        for weight: ClipTextWeight
    ) -> UIFont.Weight {
        switch weight {
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        }
    }

    private func makeTextColor(
        style: ClipTextStyle
    ) -> UIColor {
        switch style.color {
        case .white:
            return .white
        case .black:
            return .black
        case .maplogLime:
            return UIColor(Color.maplogLime)
        case .warmYellow:
            return UIColor(
                red: 1,
                green: 0.82,
                blue: 0.2,
                alpha: 1
            )
        case .coral:
            return UIColor(
                red: 1,
                green: 0.35,
                blue: 0.3,
                alpha: 1
            )
        case .pink:
            return UIColor(
                red: 1,
                green: 0.42,
                blue: 0.65,
                alpha: 1
            )
        case .lavender:
            return UIColor(
                red: 0.68,
                green: 0.58,
                blue: 1,
                alpha: 1
            )
        case .skyBlue:
            return UIColor(
                red: 0.28,
                green: 0.65,
                blue: 1,
                alpha: 1
            )
        case .mint:
            return UIColor(
                red: 0.28,
                green: 0.9,
                blue: 0.7,
                alpha: 1
            )
        }
    }

    private func makeTextAlignment(
        for alignment: ClipTextAlignment
    ) -> NSTextAlignment {
        switch alignment {
        case .leading:
            return .left
        case .center:
            return .center
        case .trailing:
            return .right
        }
    }

    private func applyContainerStyle(
        _ style: ClipTextContainerStyle
    ) {
        switch style {
        case .none:
            backgroundColor = .clear
            layer.cornerRadius = 8
            layer.borderWidth = 0
            layer.borderColor = nil

        case .glass:
            backgroundColor = UIColor.white.withAlphaComponent(0.22)
            layer.cornerRadius = 16
            layer.borderWidth = 1
            layer.borderColor = UIColor.white
                .withAlphaComponent(0.55)
                .cgColor
        }
    }




    // 텍스트 영역 드래그 → UIPanGestureRecognizer 처리
//    x 버튼 탭 → UIButton만 처리
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard let touchedView = touch.view else {
            return true
        }

        let touchedDeleteButton =
            touchedView === deleteButton
            || touchedView.isDescendant(of: deleteButton)

        return !touchedDeleteButton
    }
}

private final class EditorTextOverlayActiveGuideUIView: UIView {
    private let verticalGuideLayer = CAShapeLayer()
    private let horizontalGuideLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false
        backgroundColor = .clear
        isHidden = true

        configure(verticalGuideLayer)
        configure(horizontalGuideLayer)

        layer.addSublayer(verticalGuideLayer)
        layer.addSublayer(horizontalGuideLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(
        verticalX: CGFloat?,
        horizontalY: CGFloat?
    ) {
        isHidden = verticalX == nil && horizontalY == nil

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        verticalGuideLayer.isHidden = verticalX == nil
        horizontalGuideLayer.isHidden = horizontalY == nil

        if let verticalX {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: verticalX, y: 0))
            path.addLine(to: CGPoint(x: verticalX, y: bounds.height))
            verticalGuideLayer.path = path.cgPath
        }

        if let horizontalY {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: horizontalY))
            path.addLine(to: CGPoint(x: bounds.width, y: horizontalY))
            horizontalGuideLayer.path = path.cgPath
        }

        CATransaction.commit()
    }

    func hide() {
        isHidden = true
    }

    private func configure(
        _ layer: CAShapeLayer
    ) {
        layer.strokeColor = UIColor.systemCyan.cgColor
        layer.lineWidth = 2
        layer.lineCap = .round
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 2
        layer.shadowOffset = .zero
    }
}
