import Foundation

/// Normalized musical measurements produced by audio analysis.
struct AudioMetrics: Equatable, Sendable {
    var rmsLevel: Float
    var peakLevel: Float
    var bassEnergy: Float
    var midEnergy: Float
    var trebleEnergy: Float
    var spectralCentroid: Float
    var transientStrength: Float

    init(
        rmsLevel: Float = 0,
        peakLevel: Float = 0,
        bassEnergy: Float = 0,
        midEnergy: Float = 0,
        trebleEnergy: Float = 0,
        spectralCentroid: Float = 0,
        transientStrength: Float = 0
    ) {
        self.rmsLevel = Self.normalized(rmsLevel)
        self.peakLevel = Self.normalized(peakLevel)
        self.bassEnergy = Self.normalized(bassEnergy)
        self.midEnergy = Self.normalized(midEnergy)
        self.trebleEnergy = Self.normalized(trebleEnergy)
        self.spectralCentroid = Self.normalized(spectralCentroid)
        self.transientStrength = Self.normalized(transientStrength)
    }

    static let silence = AudioMetrics()

    private static func normalized(_ value: Float) -> Float {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}
