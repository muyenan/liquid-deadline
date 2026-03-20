import Combine
import CoreMotion
import SwiftUI

enum MotionRuntimeSupport {
    static var isSupported: Bool {
#if targetEnvironment(macCatalyst)
        return false
#else
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac == false
        }
        return true
#endif
    }
}

@MainActor
final class MotionManager: ObservableObject {
    struct LiquidState {
        var wavePhase: CGFloat = 0
        var waveAmplitude: CGFloat = 0
    }

    @Published private(set) var state = LiquidState()

    private var manager: CMMotionManager?
    private var lastTimestamp: TimeInterval?
    private var waveEnergy: CGFloat = 0
    private let maxWaveEnergy: CGFloat = 1.55
    private let maxWaveAmplitude: CGFloat = 0.18

    var liquidWavePhase: CGFloat { state.wavePhase }
    var liquidWaveAmplitude: CGFloat { state.waveAmplitude }

    init() {
        guard MotionRuntimeSupport.isSupported else { return }
        start()
    }

    deinit {
        manager?.stopDeviceMotionUpdates()
    }

    private func start() {
        guard MotionRuntimeSupport.isSupported else { return }

        let manager = CMMotionManager()
        guard manager.isDeviceMotionAvailable else { return }

        self.manager = manager
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let timestamp = data.timestamp
            let dt: CGFloat
            if let lastTimestamp {
                dt = CGFloat(min(max(timestamp - lastTimestamp, 1.0 / 120.0), 1.0 / 20.0))
            } else {
                dt = 1.0 / 60.0
            }
            self.lastTimestamp = timestamp

            let ax = CGFloat(data.userAcceleration.x)
            let ay = CGFloat(data.userAcceleration.y)
            let az = CGFloat(data.userAcceleration.z)
            let acceleration = min(hypot(ax, hypot(ay, az)), 2.8)

            let energyInjection = min(acceleration * 0.22, 0.42)
            waveEnergy = min(maxWaveEnergy, waveEnergy * exp(-2.6 * dt) + energyInjection)

            var nextState = self.state
            let baseAmplitude: CGFloat = 0.01
            nextState.waveAmplitude = min(baseAmplitude + waveEnergy * 0.085, maxWaveAmplitude)

            let basePhaseSpeed: CGFloat = 0.16
            let phaseSpeed = basePhaseSpeed + waveEnergy * 0.8
            nextState.wavePhase += phaseSpeed * dt * .pi
            if nextState.wavePhase > 10_000 {
                nextState.wavePhase.formTruncatingRemainder(dividingBy: (.pi * 2))
            }

            self.state = nextState
        }
    }
}
