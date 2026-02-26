import SwiftUI

struct OilProgressBarView: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let cornerRadius = proxy.size.height / 2
            let clampedProgress = min(max(progress, 0), 1)
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.22))

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)

                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.96), tint.opacity(0.62)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .frame(width: proxy.size.width * clampedProgress)

                    Spacer(minLength: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .frame(height: 26)
    }
}
