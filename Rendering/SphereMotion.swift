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
    static let bassSpringStrength: Float = 22
    static let bassDamping: Float = 6.6
    static let lowMidSpringStrength: Float = 16
    static let lowMidDamping: Float = 5.4
    static let beatSpringStrength: Float = 30
    static let beatDamping: Float = 5.6
    static let beatVelocityImpulse: Float = 6.5

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
    private var previousBeatPulse: Float = 0

    mutating func update(
        state: VisualizerState,
        time: Float,
        deltaTime: Float
    ) -> SphereMotionResponse {
        let bassEnvelope = (state.subBass * 0.35) + (state.bass * 0.65)
        let bassTarget = bassEnvelope * sin((time * 2.0) - 0.35)
        let lowMidTarget = state.lowMids * sin((time * 1.24) + 0.55)
        let beatRise = max(state.beatPulse - previousBeatPulse, 0)
        previousBeatPulse = state.beatPulse

        return SphereMotionResponse(
            bass: bassSpring.update(target: bassTarget, deltaTime: deltaTime),
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
        velocity = SphereMath.clamp(velocity, lowerBound: -8, upperBound: 8)
        return position
    }

    mutating func reset() {
        position = 0
        velocity = 0
    }
}

enum SphereMotion {
    static let ambientRotationRate = (2 * Float.pi) / 48
    static let idleBreathingStrength: Float = 0.014
    static let idleWaveStrength: Float = 0.009
    static let idleLobeStrength: Float = 0.006
    static let bassBreathingStrength: Float = 0.085
    static let lowMidWaveStrength: Float = 0.090
    static let midDeformationStrength: Float = 0.060
    static let trebleDetailStrength: Float = 0.0075
    static let beatImpulseStrength: Float = 0.090
    static let minimumRadius: Float = 0.90
    static let maximumRadius: Float = 1.14

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

        // The signed spring position makes the whole sphere inhale, overshoot,
        // contract below neutral, and rebound instead of only scaling outward.
        let bassBreathing = response.bass * bassBreathingStrength

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

        let trebleField = sin(
            (base.x * 13.0)
                + (base.y * 11.0)
                + (base.z * 9.0)
                + (time * 1.52)
        )
        let deformationGain = 0.60 + (state.energy * 0.65)
        let surfaceGain = 0.82 + (state.surfaceDisplacement * 0.28)
        let lowMidDrive = (state.lowMids * 0.34) + (response.lowMids * 0.66)
        let lowMidWaves = lowMidField
            * lowMidDrive
            * lowMidWaveStrength
            * deformationGain
            * surfaceGain
        let localizedMids = midField
            * state.mids
            * midDeformationStrength
            * deformationGain
        let trebleDetail = trebleField
            * state.treble
            * trebleDetailStrength
            * deformationGain
        let beatImpulse = response.beat * beatImpulseStrength

        let radialOffset = idleBreathing
            + idleTravelingWave
            + idleMigratingLobe
            + bassBreathing
            + lowMidWaves
            + localizedMids
            + trebleDetail
            + beatImpulse
        let radius = SphereMath.clamp(
            1 + radialOffset,
            lowerBound: minimumRadius,
            upperBound: maximumRadius
        )

        return base * radius
    }
}
