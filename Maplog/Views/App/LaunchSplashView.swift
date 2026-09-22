import SwiftUI

/// 번들 사진만 사용해 네트워크가 느린 상황에서도 즉시 표시하는 시작 화면입니다.
struct LaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isRevealing: Bool

    @State private var hasEntered = false
    @State private var revealScale: CGFloat = 0
    @State private var contentOpacity: Double = 1

    private let ink = Color(red: 36 / 255, green: 37 / 255, blue: 34 / 255)
    private let muted = Color(red: 115 / 255, green: 117 / 255, blue: 109 / 255)

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width, 500)
            let height = proxy.size.height

            ZStack {
                Color("LaunchBackground")
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Text("maplog")
                            .font(.system(size: width * 0.085, weight: .heavy))
                            .tracking(-width * 0.004)
                        Spacer()
                        Text("MAKE IT\nA MEMORY.")
                            .font(.system(size: width * 0.022, weight: .medium))
                            .tracking(1.2)
                            .foregroundStyle(muted)
                    }
                    Spacer()
                }
                .padding(.horizontal, width * 0.08)
                .padding(.top, max(proxy.safeAreaInsets.top + 20, height * 0.11))
                .frame(width: width)

                photoStack(width: width, height: height)
                    .scaleEffect(isRevealing && !reduceMotion ? 1.18 : 1)
                    .animation(.easeIn(duration: 0.24), value: isRevealing)

                VStack(alignment: .leading, spacing: 12) {
                    Text("A LITTLE MOMENT. A BIG MEMORY.")
                        .font(.system(size: width * 0.022, weight: .medium))
                        .tracking(0.7)
                        .foregroundStyle(muted)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("어디로든,")
                        Text("기억이 될 곳으로.")
                            .background(alignment: .bottom) {
                                Color.maplogLime.frame(height: width * 0.02)
                            }
                    }
                    .font(.system(size: width * 0.09, weight: .semibold))
                    .tracking(-width * 0.005)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: width * 0.84, alignment: .leading)
                .position(x: proxy.size.width / 2, y: height * 0.79)
                .opacity(hasEntered || reduceMotion ? 1 : 0)
                .offset(y: hasEntered || reduceMotion ? 0 : 14)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.35).delay(0.4), value: hasEntered)

                if !reduceMotion {
                    Circle()
                        .fill(Color.maplogLime)
                        .frame(width: max(proxy.size.width, height) * 2)
                        .scaleEffect(revealScale)
                        .position(x: proxy.size.width / 2, y: height * 0.45)
                }
            }
            .foregroundStyle(ink)
        }
        .ignoresSafeArea()
        .opacity(contentOpacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("맵로그")
        .accessibilityIdentifier("launch-splash")
        .task { hasEntered = true }
        .task(id: isRevealing) {
            guard isRevealing else { return }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.24)) { revealScale = 1 }
                do { try await Task.sleep(for: .milliseconds(240)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) { contentOpacity = 0 }
        }
    }

    private func photoStack(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            postcard("log_busan_night", caption: "BUSAN · AFTER DARK", width: width)
                .rotationEffect(.degrees(hasEntered || reduceMotion ? -16 : -85))
                .offset(x: hasEntered || reduceMotion ? -width * 0.14 : -width, y: -height * 0.025)
                .animation(reduceMotion ? nil : .spring(response: 0.75, dampingFraction: 0.8), value: hasEntered)
            postcard("event_jinju_garden_hero", caption: "JINJU · GOLDEN HOUR", width: width)
                .rotationEffect(.degrees(hasEntered || reduceMotion ? 14 : 75))
                .offset(x: hasEntered || reduceMotion ? width * 0.15 : width)
                .animation(reduceMotion ? nil : .spring(response: 0.75, dampingFraction: 0.8).delay(0.12), value: hasEntered)
            postcard("log_jeju_sunrise", caption: "JEJU · FIRST LIGHT", width: width)
                .rotationEffect(.degrees(hasEntered || reduceMotion ? -3 : 60))
                .offset(y: hasEntered || reduceMotion ? height * 0.018 : height)
                .animation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.82).delay(0.24), value: hasEntered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -height * 0.005)
        .accessibilityHidden(true)
    }

    private func postcard(_ asset: String, caption: String, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(asset)
                .resizable()
                .scaledToFill()
                .frame(width: width * 0.57, height: width * 0.76)
                .clipped()
            Text(caption)
                .font(.system(size: width * 0.022, weight: .medium))
                .tracking(0.8)
                .padding(.horizontal, 5)
                .padding(.bottom, 4)
        }
        .padding(6)
        .background(.white, in: RoundedRectangle(cornerRadius: 5))
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 8)
    }
}

#Preview {
    LaunchSplashView(isRevealing: false)
}
