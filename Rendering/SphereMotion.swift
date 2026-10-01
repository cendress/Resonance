import Foundation
import simd

enum SphereMotion {
    static func orientation(at time: Float, state: VisualizerState) -> SIMD3<Float> {
        let audioRate = state.rotationRate * 0.42
        return SIMD3<Float>(
            0.19 + (sin(time * 0.071) * 0.08),
            time * (0.055 + audioRate),
            -0.10 + (cos(time * 0.047) * 0.045)
        )
    }

    static func deformedVertex(
        _ base: SIMD3<Float>,
        index: Int,
        time: Float,
        state: VisualizerState
    ) -> SIMD3<Float> {
        let phase = Float(index) * 0.618_034
        let ambient = SphereMath.organicWave(base, phase: phase, time: time)
        let breathing = sin(time * 0.72) * 0.007

        let broadBass = sin((time * 1.12) + (base.y * 1.35))
            * ((state.subBass * 0.020) + (state.bass * 0.035))
        let rollingLowMids = sin(
            (base.x * 2.7) + (base.y * 1.8) - (base.z * 1.2) + (time * 0.83)
        ) * state.lowMids * 0.047

        let localizedEnvelope = pow(max((base.y + 1) * 0.5, 0), 1.7)
        let localizedMids = sin(
            (base.x * 6.2) - (base.z * 5.4) + (time * 1.53) + phase
        ) * localizedEnvelope * state.mids * 0.026
        let fineTreble = sin(
            (base.x * 14.0) + (base.y * 11.0) + (base.z * 9.0) + (time * 3.1) + phase
        ) * state.treble * 0.009

        let audioStrength = 0.45 + (state.energy * 0.55)
        let beatImpulse = state.beatPulse * 0.060
        let radialOffset = breathing
            + (ambient * 0.0055)
            + ((broadBass + rollingLowMids + localizedMids + fineTreble) * audioStrength)
            + beatImpulse
        let radius = SphereMath.clamp(1 + radialOffset, lowerBound: 0.88, upperBound: 1.16)

        let referenceAxis = abs(base.y) > 0.88
            ? SIMD3<Float>(1, 0, 0)
            : SIMD3<Float>(0, 1, 0)
        let tangent = SphereMath.normalize(simd_cross(base, referenceAxis))
        let tangentialAmount = (0.0018 + (state.treble * 0.0032))
            * sin((time * 0.91) + (phase * 1.3))

        return SphereMath.normalize((base * radius) + (tangent * tangentialAmount)) * radius
    }
}
