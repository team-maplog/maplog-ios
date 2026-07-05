import SwiftUI

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.bold)
            }
            .font(.system(size: 16))
            .foregroundStyle(Color.maplogInk)
            .frame(maxWidth: .infinity)
            .frame(height: MaplogSize.primaryButtonHeight)
            .background(Color.maplogLime)
            .clipShape(RoundedRectangle(cornerRadius: MaplogSpacing.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ChipView: View {
    let title: String
    var isSelected = false

    var body: some View {
        MaplogFilterChip(title: title, isSelected: isSelected)
    }
}
