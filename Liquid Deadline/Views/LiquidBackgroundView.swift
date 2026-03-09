import SwiftUI

struct LiquidBackgroundView: View {
    let backgroundStyle: BackgroundStyleOption

    var body: some View {
        switch backgroundStyle {
        case .white:
            Color.white.ignoresSafeArea()
        case .pinkWhiteGradient:
            pinkWhiteGradientBackground
        case .blueWhiteGradient:
            blueWhiteGradientBackground
        }
    }

    private var pinkWhiteGradientBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.95, blue: 0.97),
                    Color(red: 1.0, green: 0.90, blue: 0.94),
                    Color(red: 0.98, green: 0.86, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: -150, y: -210)

            Circle()
                .fill(Color(red: 1.0, green: 0.80, blue: 0.88).opacity(0.42))
                .frame(width: 240, height: 240)
                .blur(radius: 55)
                .offset(x: 150, y: 220)
        }
    }

    private var blueWhiteGradientBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.97, blue: 1.0),
                    Color(red: 0.87, green: 0.93, blue: 1.0),
                    Color(red: 0.79, green: 0.88, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.58))
                .frame(width: 320, height: 320)
                .blur(radius: 65)
                .offset(x: -150, y: -220)

            Circle()
                .fill(Color(red: 0.72, green: 0.84, blue: 1.0).opacity(0.40))
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .offset(x: 150, y: 210)
        }
    }
}
