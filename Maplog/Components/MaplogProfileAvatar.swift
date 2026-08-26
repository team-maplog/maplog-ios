import SwiftUI
import UIKit

/// 인증이 필요한 프로필 이미지 데이터를 화면에서 일관되게 표시합니다.
/// 네트워크 요청은 ViewModel이 담당하고, 이 View는 받은 데이터만 그립니다.
struct MaplogProfileAvatar: View {
    let imageData: Data?
    let nickname: String
    let size: CGFloat
    let fallbackBackground: Color
    let fallbackForeground: Color
    let borderColor: Color?

    init(
        imageData: Data?,
        nickname: String,
        size: CGFloat,
        fallbackBackground: Color = Color.maplogCanvas,
        fallbackForeground: Color = Color.maplogInk,
        borderColor: Color? = nil
    ) {
        self.imageData = imageData
        self.nickname = nickname
        self.size = size
        self.fallbackBackground = fallbackBackground
        self.fallbackForeground = fallbackForeground
        self.borderColor = borderColor
    }

    private var fallbackInitial: String {
        String(nickname.prefix(1))
    }

    var body: some View {
        Group {
            if let imageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(fallbackInitial)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(fallbackForeground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(fallbackBackground)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if let borderColor {
                Circle()
                    .stroke(borderColor, lineWidth: 1)
            }
        }
        .accessibilityLabel("\(nickname) 프로필 사진")
    }
}
