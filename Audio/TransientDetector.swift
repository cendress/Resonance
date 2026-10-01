import Foundation

/// Detects short energy rises and turns them into a fast-attack, slow-release pulse.
nonisolated struct TransientDetector: Sendable {
    private var previousEnergy: Float = 0
    private var fastEnvelope: Float = 0
    private var slowEnvelope: Float = 0
    private var pulse: Float = 0

    private let onsetThreshold: Float
    private let attack: Float
    private let release: Float

    init(
        onsetThreshold: Float = 0.035,
        attack: Float = 0.88,
        release: Float = 0.12
    ) {
        self.onsetThreshold = max(onsetThreshold, 0)
        self.attack = min(max(attack, 0), 1)
        self.release = min(max(release, 0), 1)
    }

    mutating func detect(energy: Float) -> Float {
        let current = min(max(energy.isFinite ? energy : 0, 0), 1)
        fastEnvelope += (current - fastEnvelope) * 0.42
        slowEnvelope += (current - slowEnvelope) * (current > slowEnvelope ? 0.025 : 0.06)

        let immediateRise = max(current - previousEnergy, 0)
        let envelopeRise = max(fastEnvelope - slowEnvelope, 0)
        let adaptiveThreshold = onsetThreshold + (slowEnvelope * 0.11)
        let onset = max((immediateRise * 0.72) + (envelopeRise * 0.45) - adaptiveThreshold, 0)
        let candidate = min(onset * 7.5, 1)

        let factor = candidate > pulse ? attack : release
        pulse += (candidate - pulse) * factor
        previousEnergy = current
        return min(max(pulse, 0), 1)
    }

    mutating func reset() {
        previousEnergy = 0
        fastEnvelope = 0
        slowEnvelope = 0
        pulse = 0
    }
}
