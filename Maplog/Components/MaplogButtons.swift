import SwiftUI

enum MaplogButtonVariant {
    case primary
    case secondary
    case tonal
    case text
    case destructive
    case brand(background: Color, foreground: Color)
}

enum MaplogButtonSize {
    case compact
    case regular
    case large

    var height: CGFloat {
        switch self {
        case .compact: return MaplogSize.compactControlHeight
        case .regular: return MaplogSize.controlHeight
        case .large: return MaplogSize.primaryButtonHeight
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .compact: return MaplogSpacing.small
        case .regular: return MaplogSpacing.medium
        case .large: return MaplogSpacing.large
        }
    }

    var font: Font {
        switch self {
        case .compact: return MaplogFont.calloutStrong
        case .regular, .large: return MaplogFont.button
        }
    }
}

struct MaplogButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var variant: MaplogButtonVariant = .primary
    var size: MaplogButtonSize = .regular
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, variant.isText ? MaplogSpacing.xxSmall : size.horizontalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: variant.isText ? MaplogSize.minimumTapTarget : size.height)
            .background(backgroundColor(configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: variant.isText ? MaplogRadius.small : MaplogRadius.medium, style: .continuous))
            .overlay {
                if variant.hasBorder {
                    RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                        .stroke(Color.maplogTextPrimary, lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.48)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .secondary, .tonal, .text: return .maplogTextPrimary
        case .destructive: return .white
        case .brand(_, let foreground): return foreground
        }
    }

    private func backgroundColor(_ isPressed: Bool) -> Color {
        guard isEnabled else { return .maplogBorder }
        switch variant {
        case .primary:
            return isPressed ? .maplogPrimaryPressed : .maplogPrimary
        case .secondary:
            return isPressed ? .maplogCanvas : .maplogSurface
        case .tonal:
            return isPressed ? .maplogBorder : .maplogCanvas
        case .text:
            return isPressed ? .maplogCanvas : .clear
        case .destructive:
            return isPressed ? .maplogDanger.opacity(0.82) : .maplogDanger
        case .brand(let background, _):
            return isPressed ? background.opacity(0.78) : background
        }
    }
}

/// 아이콘 버튼과 지도 핀처럼 컴팩트한 컨트롤에 쓰는 짧은 누름 피드백입니다.
struct MaplogPressFeedbackStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private extension MaplogButtonVariant {
    var hasBorder: Bool {
        if case .secondary = self { return true }
        return false
    }

    var isText: Bool {
        if case .text = self { return true }
        return false
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String?
    var isEnabled = true
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: MaplogSpacing.xSmall) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(MaplogButtonStyle(variant: .primary, size: .large, fullWidth: true))
        .disabled(!isEnabled)
    }
}

struct ChipView: View {
    let title: String
    var isSelected = false

    var body: some View {
        MaplogFilterChip(title: title, isSelected: isSelected)
    }
}
