import Foundation
import simd

enum SphereMotion {
    static let ambientRotationRate = (2 * Float.pi) / 48
    static let idleBreathingStrength: Float = 0.0065
    static let bassBreathingStrength: Float = 0.055
    static let lowMidWaveStrength: Float = 0.052
    static let midDeformationStrength: Float = 0.030
    static let trebleDetailStrength: Float = 0.0045
    static let beatImpulseStrength: Float = 0.052

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
        index: Int,
        time: Float,
        state: VisualizerState
    ) -> SIMD3<Float> {
        let spatialPhase = (base.x * 2.1) + (base.y * 3.7) + (base.z * 4.3)
        let ambient = SphereMath.organicWave(
            base,
            phase: spatialPhase,
            time: time
        )
        let idleBreathing = sin(time * 0.68) * idleBreathingStrength
        let idleSurfaceMotion = ambient * 0.0045

        // Bass stays broad and coherent across the entire sphere. The smoothed
        // band envelope supplies the attack/release; this slow oscillator adds elasticity.
        let bassEnvelope = (state.subBass * 0.35) + (state.bass * 0.65)
        let bassCycle = 0.35 + (sin(time * 1.70) * 0.65)
        let bassBreathing = bassEnvelope * bassBreathingStrength * bassCycle

        // Two low-frequency spatial fields create large waves traveling in
        // different directions rather than a single uniform wobble.
        let firstLowMidWave = sin(
            (base.x * 2.5) + (base.y * 1.7) - (base.z * 1.3) - (time * 0.92)
        )
        let secondLowMidWave = sin(
            (-base.x * 1.4) + (base.y * 2.2) + (base.z * 2.6) + (time * 0.61)
        )
        let lowMidField = (firstLowMidWave * 0.68) + (secondLowMidWave * 0.32)

        // A slowly moving focus confines midrange movement to organic lobes.
        let midFocus = SphereMath.normalize(
            SIMD3<Float>(
                sin(time * 0.19),
                cos((time * 0.16) + 0.7),
                sin((time * 0.13) + 1.4)
            )
        )
        let midEnvelope = pow(max(simd_dot(base, midFocus), 0), 2.4)
        let midField = sin(
            (base.x * 5.1) - (base.y * 3.8) + (base.z * 4.4) - (time * 1.18)
        )

        let trebleField = sin(
            (base.x * 13.0) + (base.y * 11.0) + (base.z * 9.0) + (time * 1.85)
        )
        let deformationGain = 0.72 + (state.energy * 0.28)
        let surfaceGain = 0.86 + (state.surfaceDisplacement * 0.14)
        let lowMidWaves = lowMidField
            * state.lowMids
            * lowMidWaveStrength
            * deformationGain
            * surfaceGain
        let localizedMids = midField
            * midEnvelope
            * state.mids
            * midDeformationStrength
            * deformationGain
        let trebleDetail = trebleField
            * state.treble
            * trebleDetailStrength
            * deformationGain
        let beatImpulse = state.beatPulse * beatImpulseStrength

        let radialOffset = idleBreathing
            + idleSurfaceMotion
            + bassBreathing
            + lowMidWaves
            + localizedMids
            + trebleDetail
            + beatImpulse
        let radius = SphereMath.clamp(1 + radialOffset, lowerBound: 0.90, upperBound: 1.14)

        return base * radius
    }
}
