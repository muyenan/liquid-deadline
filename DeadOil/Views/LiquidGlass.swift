import SwiftUI

struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 22

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
        } else {
            content
                .padding(14)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.1), radius: 12, y: 8)
        }
    }
}

extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius))
    }
}
