import SwiftUI

/// 내 프로필과 릴스에서 여는 프로필이 공유하는 사진·소개 배치입니다.
struct ProfileIdentityHeader: View {
    let nickname: String
    let bio: String
    let imageData: Data?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            MaplogProfileAvatar(
                imageData: imageData,
                nickname: nickname,
                size: ProfileLayout.avatarSize,
                fallbackBackground: Color.maplogCanvas,
                fallbackForeground: Color.maplogOlive,
                borderColor: .white.opacity(0.64)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(nickname)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                if !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

enum ProfileLayout {
    static let avatarSize: CGFloat = 76
    static let headerInset: CGFloat = 18
    // 열 너비는 유지하고, 5:6보다 세로 길이만 약 7% 줄입니다.
    static let thumbnailAspectRatio: CGFloat = 9 / 10
}
