import SwiftUI

struct MaplogLogoView: View {
    var compact = false

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(Color.maplogLime)
                Image(systemName: "mappin")
                    .font(.system(size: compact ? 13 : 16, weight: .black))
                    .foregroundStyle(Color.maplogOnPrimary)
            }
            .frame(width: compact ? 24 : 30, height: compact ? 24 : 30)

            Text("Maplog")
                .font(.system(size: compact ? 16 : 21, weight: .black, design: .rounded))
                .foregroundStyle(Color.maplogInk)
        }
    }
}
