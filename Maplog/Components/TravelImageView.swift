import SwiftUI

struct TravelImageView: View {
    let style: PhotoStyle
    var height: CGFloat
    var cornerRadius: CGFloat = MaplogSpacing.cardRadius
    var showsSymbol = true

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(style.assetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )

            if showsSymbol {
                Image(systemName: style.symbol)
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(18)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var colors: [Color] {
        switch style {
        case .mountain:
            return [Color(red: 0.24, green: 0.35, blue: 0.31), Color(red: 0.71, green: 0.84, blue: 0.66)]
        case .ocean:
            return [Color(red: 0.06, green: 0.38, blue: 0.62), Color(red: 0.63, green: 0.86, blue: 0.91)]
        case .city:
            return [Color(red: 0.08, green: 0.10, blue: 0.13), Color(red: 0.67, green: 0.72, blue: 0.72)]
        case .night:
            return [Color(red: 0.05, green: 0.06, blue: 0.12), Color(red: 0.27, green: 0.32, blue: 0.55)]
        case .cafe:
            return [Color(red: 0.34, green: 0.25, blue: 0.18), Color(red: 0.83, green: 0.74, blue: 0.60)]
        case .forest:
            return [Color(red: 0.12, green: 0.40, blue: 0.27), Color(red: 0.70, green: 0.86, blue: 0.49)]
        case .temple:
            return [Color(red: 0.46, green: 0.20, blue: 0.18), Color(red: 0.88, green: 0.74, blue: 0.47)]
        case .market:
            return [Color(red: 0.66, green: 0.23, blue: 0.20), Color(red: 0.95, green: 0.73, blue: 0.35)]
        case .festival:
            return [Color(red: 0.96, green: 0.52, blue: 0.62), Color(red: 0.30, green: 0.62, blue: 0.92)]
        case .palace:
            return [Color(red: 0.16, green: 0.24, blue: 0.20), Color(red: 0.76, green: 0.55, blue: 0.31)]
        case .alley:
            return [Color(red: 0.44, green: 0.31, blue: 0.20), Color(red: 0.78, green: 0.67, blue: 0.50)]
        }
    }
}
