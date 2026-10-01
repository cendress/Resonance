import Foundation

/// Slow-moving musical context used for atmosphere and palette decisions.
nonisolated struct RollingMusicCharacter: Equatable, Sendable {
    private(set) var rollingEnergy: Float = 0
    private(set) var rollingBrightness: Float = 0
    private(set) var rollingBassPresence: Float = 0
    private(set) var rollingRhythmicActivity: Float = 0
    private(set) var rollingIntensity: Float = 0
    private(set) var rollingDynamicRange: Float = 0

    /// Longer memories keep palette changes deliberate rather than twitchy.
    private(set) var longTermEnergy: Float = 0
    private(set) var longTermBrightness: Float = 0
    private(set) var longTermBassPresence: Float = 0
    private(set) var longTermRhythmicActivity: Float = 0

    private var energyFloor: Float = 0
    private var energyCeiling: Float = 0

    // Compatibility accessors used by PaletteSelector.
    var energy: Float { rollingEnergy }
    var brightness: Float { rollingBrightness }
    var bassPresence: Float { rollingBassPresence }
    var rhythmicActivity: Float { rollingRhythmicActivity }

    mutating func update(with metrics: AudioMetrics) {
        let bassPresence = max(metrics.subBass, metrics.bass)
        let intensity = min(
            (metrics.energy * 0.48)
                + (metrics.loudness * 0.27)
                + (metrics.beatPulse * 0.25),
            1
        )

        rollingEnergy = Self.follow(rollingEnergy, metrics.energy, attack: 0.08, release: 0.025)
        rollingBrightness = Self.follow(rollingBrightness, metrics.brightness, attack: 0.045, release: 0.018)
        rollingBassPresence = Self.follow(rollingBassPresence, bassPresence, attack: 0.065, release: 0.022)
        rollingRhythmicActivity = Self.follow(
            rollingRhythmicActivity,
            metrics.beatPulse,
            attack: 0.11,
            release: 0.025
        )
        rollingIntensity = Self.follow(rollingIntensity, intensity, attack: 0.075, release: 0.02)

        energyFloor = Self.follow(energyFloor, metrics.energy, attack: 0.004, release: 0.055)
        energyCeiling = Self.follow(energyCeiling, metrics.energy, attack: 0.12, release: 0.006)
        rollingDynamicRange = Self.follow(
            rollingDynamicRange,
            max(energyCeiling - energyFloor, 0),
            attack: 0.04,
            release: 0.012
        )

        longTermEnergy = Self.follow(longTermEnergy, rollingEnergy, attack: 0.009, release: 0.004)
        longTermBrightness = Self.follow(longTermBrightness, rollingBrightness, attack: 0.007, release: 0.003)
        longTermBassPresence = Self.follow(longTermBassPresence, rollingBassPresence, attack: 0.008, release: 0.003)
        longTermRhythmicActivity = Self.follow(
            longTermRhythmicActivity,
            rollingRhythmicActivity,
            attack: 0.01,
            release: 0.004
        )
    }

    mutating func reset() {
        self = RollingMusicCharacter()
    }

    private static func follow(
        _ current: Float,
        _ target: Float,
        attack: Float,
        release: Float
    ) -> Float {
        let factor = target > current ? attack : release
        return current + ((target - current) * factor)
    }
}
