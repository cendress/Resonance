import Foundation
import simd

struct ProjectedSpherePoint: Equatable, Sendable {
    let position: SIMD2<Float>
    let depth: Float
    let perspectiveScale: Float
}

enum SphereMath {
    static func clamp(_ value: Float, lowerBound: Float = 0, upperBound: Float = 1) -> Float {
        min(max(value.isFinite ? value : lowerBound, lowerBound), upperBound)
    }

    static func normalize(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let lengthSquared = simd_length_squared(vector)
        guard lengthSquared > 0.000_001, lengthSquared.isFinite else {
            return SIMD3<Float>(0, 1, 0)
        }
        return vector / sqrt(lengthSquared)
    }

    static func rotate(_ point: SIMD3<Float>, angles: SIMD3<Float>) -> SIMD3<Float> {
        let sinX = sin(angles.x)
        let cosX = cos(angles.x)
        let sinY = sin(angles.y)
        let cosY = cos(angles.y)
        let sinZ = sin(angles.z)
        let cosZ = cos(angles.z)

        let aroundX = SIMD3<Float>(
            point.x,
            (point.y * cosX) - (point.z * sinX),
            (point.y * sinX) + (point.z * cosX)
        )
        let aroundY = SIMD3<Float>(
            (aroundX.x * cosY) + (aroundX.z * sinY),
            aroundX.y,
            (-aroundX.x * sinY) + (aroundX.z * cosY)
        )
        return SIMD3<Float>(
            (aroundY.x * cosZ) - (aroundY.y * sinZ),
            (aroundY.x * sinZ) + (aroundY.y * cosZ),
            aroundY.z
        )
    }

    static func project(
        _ point: SIMD3<Float>,
        cameraDistance: Float = 5.6,
        focalLength: Float = 5.2
    ) -> ProjectedSpherePoint {
        let denominator = max(cameraDistance - point.z, 0.25)
        let perspective = focalLength / denominator
        return ProjectedSpherePoint(
            position: SIMD2<Float>(point.x, point.y) * perspective,
            depth: clamp((point.z + 1.5) / 3),
            perspectiveScale: perspective
        )
    }

    static func faceNormal(
        _ first: SIMD3<Float>,
        _ second: SIMD3<Float>,
        _ third: SIMD3<Float>
    ) -> SIMD3<Float> {
        normalize(simd_cross(second - first, third - first))
    }

    static func lerp(_ first: Float, _ second: Float, amount: Float) -> Float {
        first + ((second - first) * clamp(amount))
    }

    /// Smooth deterministic oscillation used instead of frame-to-frame randomness.
    static func organicWave(_ point: SIMD3<Float>, phase: Float, time: Float) -> Float {
        let first = sin((point.x * 3.1) + (point.y * 2.3) + (time * 0.71) + phase)
        let second = cos((point.z * 4.7) - (point.x * 1.9) - (time * 0.43) + (phase * 0.6))
        let third = sin((point.y * 7.3) + (point.z * 5.1) + (time * 1.17) - phase)
        return (first * 0.48) + (second * 0.34) + (third * 0.18)
    }
}
