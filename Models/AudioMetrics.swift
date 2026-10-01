import Foundation

/// A normalized snapshot of the current analysis window.
/// Every stored value is guaranteed to be in `0...1`.
nonisolated struct AudioMetrics: Equatable, Sendable {
    var subBass: Float
    var bass: Float
    var lowMids: Float
    var mids: Float
    var upperMids: Float
    var treble: Float
    var loudness: Float
    var energy: Float
    var brightness: Float
    var beatPulse: Float

    init(
        subBass: Float = 0,
        bass: Float = 0,
        lowMids: Float = 0,
        mids: Float = 0,
        upperMids: Float = 0,
        treble: Float = 0,
        loudness: Float = 0,
        energy: Float = 0,
        brightness: Float = 0,
        beatPulse: Float = 0
    ) {
        self.subBass = Self.normalized(subBass)
        self.bass = Self.normalized(bass)
        self.lowMids = Self.normalized(lowMids)
        self.mids = Self.normalized(mids)
        self.upperMids = Self.normalized(upperMids)
        self.treble = Self.normalized(treble)
        self.loudness = Self.normalized(loudness)
        self.energy = Self.normalized(energy)
        self.brightness = Self.normalized(brightness)
        self.beatPulse = Self.normalized(beatPulse)
    }

    static let silence = AudioMetrics()

    /// Compatibility names for renderer code that still speaks in the original prototype vocabulary.
    var rmsLevel: Float { loudness }
    var peakLevel: Float { energy }
    var bassEnergy: Float { max(subBass, bass) }
    var midEnergy: Float { max(lowMids, mids) }
    var trebleEnergy: Float { max(upperMids, treble) }
    var spectralCentroid: Float { brightness }
    var transientStrength: Float { beatPulse }

    private static func normalized(_ value: Float) -> Float {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}
