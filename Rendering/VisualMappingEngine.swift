import Foundation

/// The sole translation layer between normalized musical data and visual state.
struct VisualMappingEngine {
    private var energySmoother = Smoother(attack: 0.32, release: 0.09)
    private var transientSmoother = Smoother(attack: 0.65, release: 0.18)
    private var brightnessSmoother = Smoother(attack: 0.14, release: 0.08)
    private var musicCharacter = RollingMusicCharacter()
    private let paletteSelector = PaletteSelector()

    mutating func map(_ metrics: AudioMetrics) -> VisualizerState {
        musicCharacter.update(with: metrics)

        let energy = energySmoother.process(metrics.rmsLevel)
        let transient = transientSmoother.process(metrics.transientStrength)
        let brightness = brightnessSmoother.process(metrics.spectralCentroid)

        return VisualizerState(
            sphereScale: 1 + (energy * 0.16) + (transient * 0.08),
            surfaceDisplacement: (metrics.bassEnergy * 0.7) + (metrics.midEnergy * 0.3),
            pulse: transient,
            rotationRate: 0.05 + (musicCharacter.rhythmicActivity * 0.45),
            backgroundEnergy: energy,
            backgroundBrightness: 0.08 + (brightness * 0.72),
            palette: paletteSelector.palette(for: musicCharacter)
        )
    }

    mutating func reset() -> VisualizerState {
        energySmoother.reset()
        transientSmoother.reset()
        brightnessSmoother.reset()
        musicCharacter.reset()
        return .idle
    }
}
