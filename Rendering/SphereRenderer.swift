import Foundation

/// Placeholder renderer facade. It accepts visual state, never audio-engine data.
struct SphereRenderer {
    func snapshot(for state: VisualizerState) -> SphereRenderSnapshot {
        SphereRenderSnapshot(
            scale: state.sphereScale,
            displacement: state.surfaceDisplacement,
            pulse: state.pulse
        )
    }
}

struct SphereRenderSnapshot: Equatable, Sendable {
    let scale: Float
    let displacement: Float
    let pulse: Float
}
