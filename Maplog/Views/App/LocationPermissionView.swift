import SwiftUI

struct LocationPermissionView: View {
    let onAllow: () -> Void
    let onSkip: () -> Void
    let isRequesting: Bool

    init(
        onAllow: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        isRequesting: Bool = false
    ) {
        self.onAllow = onAllow
        self.onSkip = onSkip
        self.isRequesting = isRequesting
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            LocationPermissionArtwork(size: 136, iconSize: 54)
                .padding(.bottom, 38)

            LocationPermissionCopy()

            Spacer()

            LocationPermissionActions(
                primaryTitle: "위치 권한 허용",
                onAllow: onAllow,
                onSkip: onSkip,
                isRequesting: isRequesting
            )
            .padding(.bottom, 26)
        }
        .padding(.horizontal, MaplogSpacing.page)
        .background(Color.maplogSurface)
    }
}

private struct LocationPermissionArtwork: View {
    let size: CGFloat
    let iconSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.maplogLime.opacity(0.22))
                .frame(width: size, height: size)
                .blur(radius: 18)
            Circle()
                .fill(Color.maplogLime.opacity(0.18))
                .frame(width: size * 0.72, height: size * 0.72)
            Image(systemName: "location.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(Color.maplogOlive)
        }
        .frame(width: size, height: size)
    }
}

private struct LocationPermissionCopy: View {
    var body: some View {
        VStack(spacing: MaplogSpacing.small) {
            Text("지도에서 내 위치를 표시할까요?")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.maplogInk)
                .multilineTextAlignment(.center)
            Text("지도 탭에서 내 위치를 표시하고, 현재 위치로 지도를 이동할 때만 사용해요.")
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, MaplogSpacing.xLarge)
    }
}

private struct LocationPermissionActions: View {
    let primaryTitle: String
    let onAllow: () -> Void
    let onSkip: () -> Void
    let isRequesting: Bool

    init(
        primaryTitle: String,
        onAllow: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        isRequesting: Bool = false
    ) {
        self.primaryTitle = primaryTitle
        self.onAllow = onAllow
        self.onSkip = onSkip
        self.isRequesting = isRequesting
    }

    var body: some View {
        VStack(spacing: 18) {
            Button(action: onAllow) {
                Group {
                    if isRequesting {
                        ProgressView()
                            .tint(Color.maplogInk)
                    } else {
                        Text(primaryTitle)
                            .font(.system(size: 18, weight: .medium))
                    }
                }
                .foregroundStyle(Color.maplogOnPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.maplogLime)
                .clipShape(Capsule())
                .shadow(color: Color.maplogLime.opacity(0.22), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)

            Button("나중에 하기", action: onSkip)
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .buttonStyle(.plain)
        }
    }
}
