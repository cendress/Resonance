import Foundation

/// Visual-only compression for low-frequency energy. The soft knee lifts
/// ordinary bass without flattening strong hits against 1.0.
struct VisualBassMapper {
    static let noiseFloor: Float = 0.04
    static let gain: Float = 1.5
    static let exponent: Float = 0.50

    private var smoother = Smoother(attack: 0.78, release: 0.36)
    private(set) var lastRawBass: Float = 0
    private(set) var lastVisualBass: Float = 0

    static func response(_ input: Float) -> Float {
        let clamped = min(max(input.isFinite ? input : 0, 0), 1)
        guard clamped > noiseFloor else { return 0 }
        let normalized = (clamped - noiseFloor) / (1 - noiseFloor)
        let boosted = (gain * normalized) / (1 + ((gain - 1) * normalized))
        return pow(boosted, exponent)
    }

    mutating func map(subBass: Float, bass: Float) -> Float {
        lastRawBass = min(max((subBass * 0.35) + (bass * 0.65), 0), 1)
        lastVisualBass = smoother.process(Self.response(lastRawBass))
        return lastVisualBass
    }

    mutating func reset() {
        smoother.reset()
        lastRawBass = 0
        lastVisualBass = 0
    }
}

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
    private(set) var visualBassMapper = VisualBassMapper()

    private var musicCharacter = RollingMusicCharacter()
    private var paletteSelector = PaletteSelector()

    mutating func map(_ metrics: AudioMetrics) -> VisualizerState {
        let visualBass = visualBassMapper.map(
            subBass: metrics.subBass,
            bass: metrics.bass
        )
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
            // Major radial movement lives in SphereMotion's signed spring
            // response so audio can contract below neutral as well as expand.
            sphereScale: 1,
            surfaceDisplacement: min((lowFrequencyMotion * 0.72) + (detailedMotion * 0.28), 1),
            pulse: smoothed.beatPulse,
            rotationRate: SphereMotion.ambientRotationRate,
            backgroundEnergy: musicCharacter.rollingEnergy,
            backgroundBrightness: min(
                0.06
                    + (musicCharacter.rollingBrightness * 0.56)
                    + (musicCharacter.rollingIntensity * 0.20),
                1
            ),
            subBass: smoothed.subBass,
            bass: smoothed.bass,
            visualBass: visualBass,
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
        visualBassMapper.reset()
        musicCharacter.reset()
        paletteSelector.reset()
        return .idle
    }
}
