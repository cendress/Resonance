import Foundation

/// A slowly changing description of the recent musical character.
struct RollingMusicCharacter: Equatable, Sendable {
    private(set) var energy: Float = 0
    private(set) var bassPresence: Float = 0
    private(set) var brightness: Float = 0
    private(set) var rhythmicActivity: Float = 0

    mutating func update(
        with metrics: AudioMetrics,
        smoothingFactor: Float = 0.08
    ) {
        let factor = min(max(smoothingFactor, 0), 1)
        energy = Self.interpolate(energy, metrics.rmsLevel, by: factor)
        bassPresence = Self.interpolate(bassPresence, metrics.bassEnergy, by: factor)
        brightness = Self.interpolate(brightness, metrics.spectralCentroid, by: factor)
        rhythmicActivity = Self.interpolate(
            rhythmicActivity,
            metrics.transientStrength,
            by: factor
        )
    }

    mutating func reset() {
        self = RollingMusicCharacter()
    }

    private static func interpolate(_ current: Float, _ target: Float, by amount: Float) -> Float {
        current + ((target - current) * amount)
    }
}
