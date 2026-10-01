import Foundation

/// The sole translation layer between normalized musical data and visual state.
///
/// Every instantaneous metric is smoothed before it can influence a renderer.
/// Rolling character values provide the slower atmosphere and palette timescales.
struct VisualMappingEngine {
    private var subBassSmoother = Smoother(attack: 0.48, release: 0.11)
    private var bassSmoother = Smoother(attack: 0.44, release: 0.10)
    private var lowMidsSmoother = Smoother(attack: 0.38, release: 0.09)
    private var midsSmoother = Smoother(attack: 0.34, release: 0.08)
    private var upperMidsSmoother = Smoother(attack: 0.31, release: 0.075)
    private var trebleSmoother = Smoother(attack: 0.29, release: 0.07)
    private var loudnessSmoother = Smoother(attack: 0.46, release: 0.09)
    private var energySmoother = Smoother(attack: 0.42, release: 0.075)
    private var brightnessSmoother = Smoother(attack: 0.24, release: 0.055)
    private var beatSmoother = Smoother(attack: 0.82, release: 0.13)

    private var musicCharacter = RollingMusicCharacter()
    private var paletteSelector = PaletteSelector()

    mutating func map(_ metrics: AudioMetrics) -> VisualizerState {
        let smoothed = AudioMetrics(
            subBass: subBassSmoother.process(metrics.subBass),
            bass: bassSmoother.process(metrics.bass),
            lowMids: lowMidsSmoother.process(metrics.lowMids),
            mids: midsSmoother.process(metrics.mids),
            upperMids: upperMidsSmoother.process(metrics.upperMids),
            treble: trebleSmoother.process(metrics.treble),
            loudness: loudnessSmoother.process(metrics.loudness),
            energy: energySmoother.process(metrics.energy),
            brightness: brightnessSmoother.process(metrics.brightness),
            beatPulse: beatSmoother.process(metrics.beatPulse)
        )

        musicCharacter.update(with: smoothed)

        let lowFrequencyMotion = min(
            (smoothed.subBass * 0.45)
                + (smoothed.bass * 0.38)
                + (smoothed.lowMids * 0.17),
            1
        )
        let detailedMotion = min(
            (smoothed.mids * 0.46)
                + (smoothed.upperMids * 0.32)
                + (smoothed.treble * 0.22),
            1
        )

        return VisualizerState(
            sphereScale: 1
                + (smoothed.subBass * 0.014)
                + (smoothed.bass * 0.030)
                + (smoothed.loudness * 0.008)
                + (smoothed.beatPulse * 0.028),
            surfaceDisplacement: min((lowFrequencyMotion * 0.72) + (detailedMotion * 0.28), 1),
            pulse: smoothed.beatPulse,
            rotationRate: SphereMotion.ambientRotationRate
                + (musicCharacter.rollingRhythmicActivity * 0.003),
            backgroundEnergy: musicCharacter.rollingEnergy,
            backgroundBrightness: min(
                0.06
                    + (musicCharacter.rollingBrightness * 0.56)
                    + (musicCharacter.rollingIntensity * 0.20),
                1
            ),
            subBass: smoothed.subBass,
            bass: smoothed.bass,
            lowMids: smoothed.lowMids,
            mids: min((smoothed.mids * 0.72) + (smoothed.upperMids * 0.28), 1),
            treble: min((smoothed.treble * 0.78) + (smoothed.upperMids * 0.22), 1),
            energy: smoothed.energy,
            loudness: smoothed.loudness,
            brightness: smoothed.brightness,
            beatPulse: smoothed.beatPulse,
            palette: paletteSelector.palette(for: musicCharacter)
        )
    }

    mutating func reset() -> VisualizerState {
        subBassSmoother.reset()
        bassSmoother.reset()
        lowMidsSmoother.reset()
        midsSmoother.reset()
        upperMidsSmoother.reset()
        trebleSmoother.reset()
        loudnessSmoother.reset()
        energySmoother.reset()
        brightnessSmoother.reset()
        beatSmoother.reset()
        musicCharacter.reset()
        paletteSelector.reset()
        return .idle
    }
}
