import Foundation

/// The complete, renderer-facing snapshot for a single visualizer update.
struct VisualizerState: Equatable, Sendable {
    var sphereScale: Float
    var surfaceDisplacement: Float
    var pulse: Float
    var rotationRate: Float
    var backgroundEnergy: Float
    var backgroundBrightness: Float

    /// Smoothed render inputs. Views never receive raw analyzer output.
    var subBass: Float
    var bass: Float
    var lowMids: Float
    var mids: Float
    var treble: Float
    var energy: Float
    var loudness: Float
    var brightness: Float
    var beatPulse: Float
    var palette: VisualizerPalette

    static let idle = VisualizerState(
        sphereScale: 1,
        surfaceDisplacement: 0,
        pulse: 0,
        rotationRate: (2 * Float.pi) / 48,
        backgroundEnergy: 0,
        backgroundBrightness: 0.08,
        subBass: 0,
        bass: 0,
        lowMids: 0,
        mids: 0,
        treble: 0,
        energy: 0,
        loudness: 0,
        brightness: 0,
        beatPulse: 0,
        palette: PaletteLibrary.violet
    )

    static let audioReactivePreview = VisualizerState(
        sphereScale: 1,
        surfaceDisplacement: 0.52,
        pulse: 0.64,
        rotationRate: (2 * Float.pi) / 48,
        backgroundEnergy: 0.58,
        backgroundBrightness: 0.52,
        subBass: 0.55,
        bass: 0.72,
        lowMids: 0.60,
        mids: 0.48,
        treble: 0.32,
        energy: 0.67,
        loudness: 0.61,
        brightness: 0.46,
        beatPulse: 0.64,
        palette: PaletteLibrary.teal
    )
}
