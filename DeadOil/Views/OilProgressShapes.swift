import SwiftUI

struct HorizontalOilShape: Shape {
    var progress: Double
    var amplitude: CGFloat
    var phase: CGFloat
    var tilt: CGFloat
    var frequency: CGFloat = 2.2

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        guard clamped > 0 else { return Path() }

        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let midY = rect.midY
        let baseX = minX + rect.width * clamped
        let tiltFactor = tilt * 10

        var path = Path()
        path.move(to: CGPoint(x: minX, y: minY))

        let topWaveX = xAt(y: minY, baseX: baseX, midY: midY, tiltFactor: tiltFactor, minX: minX, maxX: maxX)
        path.addLine(to: CGPoint(x: topWaveX, y: minY))

        let steps = 60
        for index in 0...steps {
            let y = minY + (CGFloat(index) / CGFloat(steps)) * rect.height
            let x = xAt(y: y, baseX: baseX, midY: midY, tiltFactor: tiltFactor, minX: minX, maxX: maxX)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: minX, y: maxY))
        path.closeSubpath()
        return path
    }

    private func xAt(
        y: CGFloat,
        baseX: CGFloat,
        midY: CGFloat,
        tiltFactor: CGFloat,
        minX: CGFloat,
        maxX: CGFloat
    ) -> CGFloat {
        let normalizedY = y / max(1, midY * 2)
        let wave = sin(normalizedY * .pi * 2 * frequency + phase) * amplitude
        let tiltShift = (y - midY) * tiltFactor / max(1, midY * 2)
        return min(max(baseX + wave + tiltShift, minX), maxX)
    }
}

struct VerticalOilShape: Shape {
    var progress: Double
    var amplitude: CGFloat
    var phase: CGFloat
    var tilt: CGFloat
    var frequency: CGFloat = 2.0

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        guard clamped > 0 else { return Path() }

        let minX = rect.minX
        let maxX = rect.maxX
        let maxY = rect.maxY
        let midX = rect.midX
        let baseY = maxY - rect.height * clamped
        let tiltFactor = tilt * 10

        var path = Path()
        path.move(to: CGPoint(x: minX, y: maxY))
        path.addLine(to: CGPoint(x: maxX, y: maxY))

        let steps = 70
        for index in 0...steps {
            let x = maxX - (CGFloat(index) / CGFloat(steps)) * rect.width
            let y = yAt(x: x, baseY: baseY, midX: midX, tiltFactor: tiltFactor, minY: rect.minY, maxY: maxY)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
    }

    private func yAt(
        x: CGFloat,
        baseY: CGFloat,
        midX: CGFloat,
        tiltFactor: CGFloat,
        minY: CGFloat,
        maxY: CGFloat
    ) -> CGFloat {
        let normalizedX = x / max(1, midX * 2)
        let wave = sin(normalizedX * .pi * 2 * frequency + phase) * amplitude
        let tiltShift = (x - midX) * tiltFactor / max(1, midX * 2)
        return min(max(baseY + wave + tiltShift, minY), maxY)
    }
}
