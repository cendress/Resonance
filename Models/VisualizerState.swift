import Foundation

/// The complete, renderer-facing snapshot for a single visualizer update.
struct VisualizerState: Equatable, Sendable {
    var sphereScale: Float
    var surfaceDisplacement: Float
    var pulse: Float
    var rotationRate: Float
    var backgroundEnergy: Float
    var backgroundBrightness: Float
    var palette: VisualizerPalette

    static let idle = VisualizerState(
        sphereScale: 1,
        surfaceDisplacement: 0,
        pulse: 0,
        rotationRate: 0,
        backgroundEnergy: 0,
        backgroundBrightness: 0.08,
        palette: PaletteLibrary.midnight
    )
}
