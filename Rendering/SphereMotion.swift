import Foundation

struct SphereMotion: Equatable, Sendable {
    var rotation: Float = 0

    mutating func advance(by deltaTime: TimeInterval, state: VisualizerState) {
        rotation += state.rotationRate * Float(deltaTime)
    }
}
