import Foundation

/// Placeholder geometry container for a future native Metal renderer.
struct IcosphereGeometry: Equatable, Sendable {
    var vertices: [SIMD3<Float>] = []
    var indices: [UInt32] = []
}
