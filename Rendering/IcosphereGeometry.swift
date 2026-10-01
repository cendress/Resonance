import Foundation
import simd

struct IcosphereTriangle: Equatable, Sendable {
    let a: UInt32
    let b: UInt32
    let c: UInt32
}

/// Immutable geodesic topology. The shared visualizer mesh is generated once.
struct IcosphereGeometry: Equatable, Sendable {
    let vertices: [SIMD3<Float>]
    let faces: [IcosphereTriangle]
    let indices: [UInt32]

    static let visualizer = IcosphereGeometry(subdivisions: 2)

    init(subdivisions: Int = 2) {
        precondition((0...5).contains(subdivisions), "Icosphere subdivisions must be between 0 and 5")

        let goldenRatio = Float((1 + sqrt(5.0)) / 2)
        var generatedVertices = [
            SIMD3<Float>(-1, goldenRatio, 0), SIMD3<Float>(1, goldenRatio, 0),
            SIMD3<Float>(-1, -goldenRatio, 0), SIMD3<Float>(1, -goldenRatio, 0),
            SIMD3<Float>(0, -1, goldenRatio), SIMD3<Float>(0, 1, goldenRatio),
            SIMD3<Float>(0, -1, -goldenRatio), SIMD3<Float>(0, 1, -goldenRatio),
            SIMD3<Float>(goldenRatio, 0, -1), SIMD3<Float>(goldenRatio, 0, 1),
            SIMD3<Float>(-goldenRatio, 0, -1), SIMD3<Float>(-goldenRatio, 0, 1)
        ].map(simd_normalize)

        var generatedFaces = [
            IcosphereTriangle(a: 0, b: 11, c: 5), IcosphereTriangle(a: 0, b: 5, c: 1),
            IcosphereTriangle(a: 0, b: 1, c: 7), IcosphereTriangle(a: 0, b: 7, c: 10),
            IcosphereTriangle(a: 0, b: 10, c: 11), IcosphereTriangle(a: 1, b: 5, c: 9),
            IcosphereTriangle(a: 5, b: 11, c: 4), IcosphereTriangle(a: 11, b: 10, c: 2),
            IcosphereTriangle(a: 10, b: 7, c: 6), IcosphereTriangle(a: 7, b: 1, c: 8),
            IcosphereTriangle(a: 3, b: 9, c: 4), IcosphereTriangle(a: 3, b: 4, c: 2),
            IcosphereTriangle(a: 3, b: 2, c: 6), IcosphereTriangle(a: 3, b: 6, c: 8),
            IcosphereTriangle(a: 3, b: 8, c: 9), IcosphereTriangle(a: 4, b: 9, c: 5),
            IcosphereTriangle(a: 2, b: 4, c: 11), IcosphereTriangle(a: 6, b: 2, c: 10),
            IcosphereTriangle(a: 8, b: 6, c: 7), IcosphereTriangle(a: 9, b: 8, c: 1)
        ]

        for _ in 0..<subdivisions {
            var midpointCache: [UInt64: UInt32] = [:]
            midpointCache.reserveCapacity(generatedFaces.count * 3 / 2)
            var nextFaces: [IcosphereTriangle] = []
            nextFaces.reserveCapacity(generatedFaces.count * 4)

            func midpoint(_ first: UInt32, _ second: UInt32) -> UInt32 {
                let lower = min(first, second)
                let upper = max(first, second)
                let key = (UInt64(lower) << 32) | UInt64(upper)
                if let cached = midpointCache[key] {
                    return cached
                }

                let point = simd_normalize(
                    (generatedVertices[Int(first)] + generatedVertices[Int(second)]) * 0.5
                )
                let index = UInt32(generatedVertices.count)
                generatedVertices.append(point)
                midpointCache[key] = index
                return index
            }

            for face in generatedFaces {
                let ab = midpoint(face.a, face.b)
                let bc = midpoint(face.b, face.c)
                let ca = midpoint(face.c, face.a)
                nextFaces.append(IcosphereTriangle(a: face.a, b: ab, c: ca))
                nextFaces.append(IcosphereTriangle(a: face.b, b: bc, c: ab))
                nextFaces.append(IcosphereTriangle(a: face.c, b: ca, c: bc))
                nextFaces.append(IcosphereTriangle(a: ab, b: bc, c: ca))
            }
            generatedFaces = nextFaces
        }

        vertices = generatedVertices
        faces = generatedFaces
        indices = generatedFaces.flatMap { [$0.a, $0.b, $0.c] }
    }
}
