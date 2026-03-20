import SwiftUI

struct OilGridCellView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    let item: DeadlineItem
    let now: Date
    let usesLightText: Bool
    let liquidMotionEnabled: Bool
    let onTap: () -> Void

    private var section: DeadlineSection { item.section(at: now) }
    private var progress: Double { item.progress(at: now) }
    private var liquidTint: Color { item.progressTint(at: now) }
    private var primaryTextColor: Color { usesLightText ? .white : .black }
    private var secondaryTextColor: Color { usesLightText ? .white.opacity(0.78) : .black.opacity(0.75) }
    private var tertiaryTextColor: Color { usesLightText ? .white.opacity(0.66) : .black.opacity(0.62) }

    private var statusText: String {
        let language = languageManager.currentLanguage
        switch section {
        case .notStarted:
            return language.relativeTimeText(
                .startsIn,
                duration: Self.durationText(from: now, to: item.startDate, language: language)
            )
        case .inProgress:
            return language.relativeTimeText(
                .remaining,
                duration: Self.durationText(from: now, to: item.endDate, language: language)
            )
        case .completed:
            return language.text("Completed", "已完成")
        case .ended:
            return language.text("Ended", "已结束")
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(2)

                Text(item.category)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)

                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.caption2)
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(2)
                }

                Text(statusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(secondaryTextColor)

                Text(item.endDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(tertiaryTextColor)

                Spacer(minLength: 2)

                VerticalOilBottleView(
                    progress: progress,
                    tint: liquidTint,
                    motionEnabled: liquidMotionEnabled
                )
                .frame(height: 110)
            }
            .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .liquidGlassCard(cornerRadius: 18)
    }

    private static func durationText(from now: Date, to target: Date, language: AppLanguage) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll
        var calendar = Calendar.current
        calendar.locale = language.locale
        formatter.calendar = calendar
        let interval = max(target.timeIntervalSince(now), 0)
        return formatter.string(from: interval) ?? language.text("0m", "0分钟")
    }
}

private struct VerticalOilBottleView: View {
    let progress: Double
    let tint: Color
    let motionEnabled: Bool

    @EnvironmentObject private var motion: MotionManager

    var body: some View {
        let wavePhase = motionEnabled ? motion.liquidWavePhase : 0
        let waveAmplitude = motionEnabled ? motion.liquidWaveAmplitude : 0

        return GeometryReader { proxy in
            let cornerRadius: CGFloat = 18
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.2))

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.42), lineWidth: 1)

                WaveTiltedLiquidFillShape(
                    progress: progress,
                    phase: wavePhase,
                    waveAmplitude: waveAmplitude
                )
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.95), tint.opacity(0.58)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .overlay {
                    WaveTiltedLiquidFillShape(
                        progress: progress,
                        phase: wavePhase,
                        waveAmplitude: waveAmplitude
                    )
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
    }
}

private struct WaveTiltedLiquidFillShape: Shape {
    var progress: Double
    var phase: CGFloat
    var waveAmplitude: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, waveAmplitude) }
        set {
            phase = newValue.first
            waveAmplitude = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        guard clamped > 0 else { return Path() }

        let baseY = rect.maxY - rect.height * clamped
        let normalizedWave = min(max(waveAmplitude, 0), 0.18)
        let liquidHeight = rect.height * clamped
        let requestedAmplitude = normalizedWave * rect.height
        let liquidBoundedAmplitude = max(liquidHeight * 0.32, 1.2)
        let amplitude = min(requestedAmplitude, liquidBoundedAmplitude)

        let minSurfaceY = rect.minY + 2
        let maxSurfaceY = rect.maxY - 2

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        let steps = 28
        for index in 0...steps {
            let t = CGFloat(index) / CGFloat(steps)
            let x = rect.maxX - rect.width * t
            let normalizedX = (x - rect.minX) / max(rect.width, 1)
            let wave = sin(normalizedX * .pi * 2.3 + phase) * amplitude
            let y = min(max(baseY + wave, minSurfaceY), maxSurfaceY)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
    }
}
