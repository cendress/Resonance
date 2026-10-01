import Foundation

/// Smooths renderer-facing state at the display cadence between audio updates.
/// The audio pipeline remains the source of truth; this only interpolates presentation.
@MainActor
final class VisualStateInterpolator {
    private var current: VisualizerState
    private var previousTime: TimeInterval?

    init(initialValue: VisualizerState? = nil) {
        current = initialValue ?? .idle
    }

    func value(toward target: VisualizerState, at time: TimeInterval) -> VisualizerState {
        guard let previousTime else {
            self.previousTime = time
            current.palette = target.palette
            return current
        }

        let deltaTime = min(max(time - previousTime, 0), 0.1)
        self.previousTime = time

        current.sphereScale = follow(
            current.sphereScale,
            target.sphereScale,
            deltaTime: deltaTime,
            attack: 0.10,
            release: 0.62
        )
        current.surfaceDisplacement = follow(
            current.surfaceDisplacement,
            target.surfaceDisplacement,
            deltaTime: deltaTime
        )
        current.pulse = follow(
            current.pulse,
            target.pulse,
            deltaTime: deltaTime,
            attack: 0.045,
            release: 0.25
        )
        current.rotationRate = follow(
            current.rotationRate,
            target.rotationRate,
            deltaTime: deltaTime,
            attack: 0.24,
            release: 0.80
        )
        current.backgroundEnergy = follow(
            current.backgroundEnergy,
            target.backgroundEnergy,
            deltaTime: deltaTime,
            attack: 0.32,
            release: 1.10
        )
        current.backgroundBrightness = follow(
            current.backgroundBrightness,
            target.backgroundBrightness,
            deltaTime: deltaTime,
            attack: 0.30,
            release: 1.20
        )
        current.subBass = follow(current.subBass, target.subBass, deltaTime: deltaTime)
        current.bass = follow(current.bass, target.bass, deltaTime: deltaTime)
        current.lowMids = follow(current.lowMids, target.lowMids, deltaTime: deltaTime)
        current.mids = follow(current.mids, target.mids, deltaTime: deltaTime)
        current.treble = follow(
            current.treble,
            target.treble,
            deltaTime: deltaTime,
            attack: 0.07,
            release: 0.30
        )
        current.energy = follow(current.energy, target.energy, deltaTime: deltaTime)
        current.loudness = follow(current.loudness, target.loudness, deltaTime: deltaTime)
        current.brightness = follow(
            current.brightness,
            target.brightness,
            deltaTime: deltaTime,
            attack: 0.16,
            release: 0.55
        )
        current.beatPulse = follow(
            current.beatPulse,
            target.beatPulse,
            deltaTime: deltaTime,
            attack: 0.045,
            release: 0.25
        )
        current.palette = target.palette
        return current
    }

    private func follow(
        _ value: Float,
        _ target: Float,
        deltaTime: TimeInterval,
        attack: TimeInterval = 0.11,
        release: TimeInterval = 0.48
    ) -> Float {
        let response = target > value ? attack : release
        let factor = Float(1 - exp(-deltaTime / max(response, 0.001)))
        return value + ((target - value) * factor)
    }
}
