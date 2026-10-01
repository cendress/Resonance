import Foundation
import simd

struct SphereMotionResponse: Equatable, Sendable {
    var bass: Float = 0
    var lowMids: Float = 0
    var beat: Float = 0

    static let zero = SphereMotionResponse()
}

/// Lightweight underdamped springs that give the mesh inertia without exposing
/// renderer state to the audio pipeline. The response is advanced once per
/// rendered frame and then shared by every vertex in that frame.
struct SphereSpringSystem: Sendable {
    static let bassSpringStrength: Float = 64
    static let bassDamping: Float = 5.6
    static let bassVelocityImpulse: Float = 10.5
    static let bassReleaseVelocityImpulse: Float = 3.2
    static let bassTransientCoupling: Float = 2.8
    static let sustainedBassTargetAmplitude: Float = 0.30
    static let sustainedBassLevelExponent: Float = 1.08
    static let sustainedBassAngularRate: Float = 7.6
    static let bassDeltaDeadZone: Float = 0.012
    static let bassDeltaExponent: Float = 0.66
    static let lowMidSpringStrength: Float = 16
    static let lowMidDamping: Float = 5.4
    static let beatSpringStrength: Float = 38
    static let beatDamping: Float = 6.6
    static let beatVelocityImpulse: Float = 8

    private var bassSpring = DampedSphereSpring(
        strength: bassSpringStrength,
        damping: bassDamping
    )
    private var lowMidSpring = DampedSphereSpring(
        strength: lowMidSpringStrength,
        damping: lowMidDamping
    )
    private var beatSpring = DampedSphereSpring(
        strength: beatSpringStrength,
        damping: beatDamping
    )
    private var previousBassEnvelope: Float = 0
    private var previousBeatPulse: Float = 0

    mutating func update(
        state: VisualizerState,
        time: Float,
        deltaTime: Float
    ) -> SphereMotionResponse {
        let visualBass = SphereMath.clamp(state.visualBass)
        let lowMids = SphereMotion.perceptualResponse(state.lowMids)
        let beatPulse = SphereMotion.perceptualResponse(state.beatPulse)
        let bassEnvelope = visualBass
        let bassTarget = pow(bassEnvelope, Self.sustainedBassLevelExponent)
            * Self.sustainedBassTargetAmplitude
            * sin(time * Self.sustainedBassAngularRate)
        let lowMidTarget = lowMids * sin((time * 1.24) + 0.55)
        let bassDelta = bassEnvelope - previousBassEnvelope
        let bassDeltaMagnitude = max(abs(bassDelta) - Self.bassDeltaDeadZone, 0)
        let responsiveBassDelta = pow(bassDeltaMagnitude, Self.bassDeltaExponent)
            * (bassDelta < 0 ? -1 : 1)
        let beatRise = max(beatPulse - previousBeatPulse, 0)
        let bassVelocityImpulse = (max(responsiveBassDelta, 0) * Self.bassVelocityImpulse)
            + (min(responsiveBassDelta, 0) * Self.bassReleaseVelocityImpulse)
            + (beatRise * bassEnvelope * Self.bassTransientCoupling)
        previousBassEnvelope = bassEnvelope
        previousBeatPulse = beatPulse

        return SphereMotionResponse(
            bass: bassSpring.update(
                target: bassTarget,
                deltaTime: deltaTime,
                velocityImpulse: bassVelocityImpulse
            ),
            lowMids: lowMidSpring.update(target: lowMidTarget, deltaTime: deltaTime),
            beat: beatSpring.update(
                target: 0,
                deltaTime: deltaTime,
                velocityImpulse: beatRise * Self.beatVelocityImpulse
            )
        )
    }

    mutating func reset() {
        bassSpring.reset()
        lowMidSpring.reset()
        beatSpring.reset()
        previousBassEnvelope = 0
        previousBeatPulse = 0
    }
}

private struct DampedSphereSpring: Sendable {
    let strength: Float
    let damping: Float
    private(set) var position: Float = 0
    private(set) var velocity: Float = 0

    mutating func update(
        target: Float,
        deltaTime: Float,
        velocityImpulse: Float = 0
    ) -> Float {
        let safeTimeStep = SphereMath.clamp(deltaTime, lowerBound: 1 / 240, upperBound: 1 / 30)
        velocity += velocityImpulse
        let acceleration = ((target - position) * strength) - (velocity * damping)
        velocity += acceleration * safeTimeStep
        position += velocity * safeTimeStep

        guard position.isFinite, velocity.isFinite else {
            reset()
            return 0
        }

        position = SphereMath.clamp(position, lowerBound: -1.15, upperBound: 1.15)
        velocity = SphereMath.clamp(velocity, lowerBound: -12, upperBound: 12)
        return position
    }

    mutating func reset() {
        position = 0
        velocity = 0
    }
}

enum SphereMotion {
    static let ambientRotationRate = (2 * Float.pi) / 48
    static let sensitivityExponent: Float = 0.62
    static let idleBreathingStrength: Float = 0.016
    static let idleWaveStrength: Float = 0.012
    static let idleLobeStrength: Float = 0.009
    static let idlePeakStrength: Float = 0.010
    static let bassPressureAmplitude: Float = 0.160
    static let bassContractionAmplitude: Float = 0.235
    static let lowMidWaveStrength: Float = 0.105
    static let midDeformationStrength: Float = 0.075
    static let dynamicPeakStrength: Float = 0.115
    static let trebleDetailStrength: Float = 0.011
    static let beatImpulseStrength: Float = 0.095
    static let beatPeakStrength: Float = 0.120
    static let beatWaveStrength: Float = 0.070
    static let minimumRadius: Float = 0.88
    static let maximumRadius: Float = 1.17

    static func perceptualResponse(_ value: Float) -> Float {
        pow(SphereMath.clamp(value), sensitivityExponent)
    }

    static func orientation(at time: Float, state: VisualizerState) -> SIMD3<Float> {
        let rotationRate = SphereMath.clamp(
            state.rotationRate,
            lowerBound: (2 * Float.pi) / 60,
            upperBound: (2 * Float.pi) / 30
        )
        return SIMD3<Float>(
            0.19 + (sin(time * 0.071) * 0.065),
            time * rotationRate,
            -0.10 + (cos(time * 0.047) * 0.038)
        )
    }

    static func deformedVertex(
        _ base: SIMD3<Float>,
        index _: Int,
        time: Float,
        state: VisualizerState,
        response: SphereMotionResponse = .zero
    ) -> SIMD3<Float> {
        let spatialPhase = (base.x * 2.1) + (base.y * 3.7) + (base.z * 4.3)
        let ambient = SphereMath.organicWave(
            base,
            phase: spatialPhase,
            time: time
        )
        let idleBreathing = sin(time * 0.63) * idleBreathingStrength
        let idleTravelingWave = (
            sin((base.x * 2.2) + (base.y * 1.3) - (time * 0.43))
                + cos((base.z * 2.0) - (base.y * 1.5) + (time * 0.37))
        ) * 0.5 * idleWaveStrength
        let idleMigratingLobe = ambient * idleLobeStrength

        // Compact cores surrounded by negative shoulders give adjacent vertices
        // visibly different radii while remaining continuous across the surface.
        let firstPeakCenter = SphereMath.normalize(
            SIMD3<Float>(
                sin((time * 0.23) + 0.4),
                cos((time * 0.17) + 1.1),
                sin((time * 0.19) + 2.4)
            )
        )
        let secondPeakCenter = SphereMath.normalize(
            SIMD3<Float>(
                cos((time * 0.15) + 2.0),
                sin((time * 0.27) + 3.2),
                cos((time * 0.20) + 0.8)
            )
        )
        let thirdPeakCenter = SphereMath.normalize(
            SIMD3<Float>(
                sin((time * 0.18) + 4.5),
                cos((time * 0.24) + 2.7),
                cos((time * 0.13) + 5.1)
            )
        )
        let fourthPeakCenter = SphereMath.normalize(
            SIMD3<Float>(
                cos((time * 0.21) + 5.5),
                sin((time * 0.16) + 0.9),
                sin((time * 0.25) + 3.8)
            )
        )
        let dynamicPeakField = SphereMath.clamp(
            peakValleyField(base, center: firstPeakCenter)
                * (0.72 + (sin((time * 0.71) + 0.3) * 0.24))
                + peakValleyField(base, center: secondPeakCenter)
                * (0.58 + (cos((time * 0.63) + 1.7) * 0.22))
                - peakValleyField(base, center: thirdPeakCenter)
                * (0.50 + (sin((time * 0.77) + 2.8) * 0.20))
                + peakValleyField(base, center: fourthPeakCenter)
                * (0.42 + (cos((time * 0.69) + 4.2) * 0.18)),
            lowerBound: -1.35,
            upperBound: 1.35
        )
        let idlePeaks = dynamicPeakField * idlePeakStrength

        // Rising bass pushes the whole membrane outward. The underdamped
        // pressure spring then crosses neutral, with a deliberately readable
        // inward stroke, before rebounding and settling.
        let bassStrokeGain = 0.75
            + (state.visualBass * 0.20)
            + (state.energy * 0.35)
        let bassPumping = response.bass >= 0
            ? response.bass * bassPressureAmplitude * bassStrokeGain
            : response.bass * bassContractionAmplitude * bassStrokeGain

        // Two low-frequency spatial fields create large waves traveling in
        // different directions rather than a single uniform wobble.
        let firstLowMidWave = sin(
            (base.x * 2.5) + (base.y * 1.7) - (base.z * 1.3) - (time * 0.92)
        )
        let secondLowMidWave = sin(
            (-base.x * 1.4) + (base.y * 2.2) + (base.z * 2.6) + (time * 0.61)
        )
        let thirdLowMidWave = cos(
            (base.x * 1.8) - (base.y * 2.8) + (base.z * 1.2) - (time * 0.74)
        )
        let lowMidField = (firstLowMidWave * 0.46)
            + (secondLowMidWave * 0.32)
            + (thirdLowMidWave * 0.22)

        // Several slowly migrating foci let separate surface regions swell and
        // contract, visibly changing triangle proportions without changing topology.
        let firstMidFocus = SphereMath.normalize(
            SIMD3<Float>(
                sin(time * 0.19),
                cos((time * 0.16) + 0.7),
                sin((time * 0.13) + 1.4)
            )
        )
        let secondMidFocus = SphereMath.normalize(
            SIMD3<Float>(
                cos((time * 0.14) + 2.1),
                sin((time * 0.21) + 0.4),
                cos((time * 0.17) + 1.2)
            )
        )
        let thirdMidFocus = SphereMath.normalize(
            SIMD3<Float>(
                sin((time * 0.12) + 4.0),
                cos((time * 0.18) + 2.7),
                sin((time * 0.15) + 0.3)
            )
        )
        let firstMidLobe = pow(max(simd_dot(base, firstMidFocus), 0), 1.9)
            * sin((time * 0.79) + 0.2)
        let secondMidLobe = pow(max(simd_dot(base, secondMidFocus), 0), 2.1)
            * sin((time * 0.67) + 2.3)
        let thirdMidLobe = pow(max(simd_dot(base, thirdMidFocus), 0), 1.8)
            * sin((time * 0.91) + 4.1)
        let midField = (firstMidLobe * 0.42)
            + (secondMidLobe * 0.34)
            + (thirdMidLobe * 0.24)
            + (
                sin(
                    (base.x * 4.2) - (base.y * 3.1) + (base.z * 3.7) - (time * 0.72)
                ) * 0.18
            )

        let trebleField = (
            sin(
                (base.x * 13.0)
                    + (base.y * 11.0)
                    + (base.z * 9.0)
                    + (time * 1.52)
            )
                + sin(
                    (-base.x * 17.0)
                        + (base.y * 14.0)
                        - (base.z * 12.0)
                        - (time * 1.21)
                )
        ) * 0.5
        let responsiveLowMids = perceptualResponse(state.lowMids)
        let responsiveMids = perceptualResponse(state.mids)
        let responsiveTreble = perceptualResponse(state.treble)
        let responsiveEnergy = perceptualResponse(state.energy)
        let responsiveSurface = perceptualResponse(state.surfaceDisplacement)
        let responsiveBeat = perceptualResponse(state.beatPulse)
        let deformationGain = 0.65 + (responsiveEnergy * 0.75)
        let surfaceGain = 0.84 + (responsiveSurface * 0.30)
        let lowMidDrive = (responsiveLowMids * 0.32) + (response.lowMids * 0.68)
        let lowMidWaves = lowMidField
            * lowMidDrive
            * lowMidWaveStrength
            * deformationGain
            * surfaceGain
        let localizedMids = midField
            * responsiveMids
            * midDeformationStrength
            * deformationGain
        let dynamicPeaks = dynamicPeakField
            * ((responsiveMids * 0.72) + (responsiveBeat * 0.28))
            * dynamicPeakStrength
            * deformationGain
        let trebleDetail = trebleField
            * responsiveTreble
            * trebleDetailStrength
            * deformationGain
        let beatImpulse = response.beat * beatImpulseStrength
        let beatPeaks = dynamicPeakField * response.beat * beatPeakStrength
        let beatDistance = 1 - SphereMath.clamp(
            simd_dot(base, firstPeakCenter),
            lowerBound: -1,
            upperBound: 1
        )
        let beatWave = sin((beatDistance * 12.5) - (time * 5.4))
            * exp(-beatDistance * 1.8)
            * response.beat
            * beatWaveStrength

        let radialOffset = idleBreathing
            + idleTravelingWave
            + idleMigratingLobe
            + idlePeaks
            + bassPumping
            + lowMidWaves
            + localizedMids
            + dynamicPeaks
            + trebleDetail
            + beatImpulse
            + beatPeaks
            + beatWave
        let radius = SphereMath.clamp(
            1 + radialOffset,
            lowerBound: minimumRadius,
            upperBound: maximumRadius
        )

        return base * radius
    }

    private static func peakValleyField(
        _ vertex: SIMD3<Float>,
        center: SIMD3<Float>
    ) -> Float {
        let alignment = SphereMath.clamp(
            simd_dot(vertex, center),
            lowerBound: -1,
            upperBound: 1
        )
        let core = pow(
            SphereMath.clamp((alignment - 0.86) / 0.14),
            1.65
        )
        let shoulder = pow(
            SphereMath.clamp((alignment - 0.48) / 0.52),
            1.20
        )
        return (core * 1.75) - (shoulder * 0.55)
    }
}
