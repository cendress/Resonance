import SwiftUI

/// A temporary SwiftUI stand-in for the future sphere renderer.
struct SphereView: View {
    let state: VisualizerState

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [state.palette.accent.color, state.palette.primary.color],
                    center: .topLeading,
                    startRadius: 4,
                    endRadius: 180
                )
            )
            .frame(width: 220, height: 220)
            .scaleEffect(CGFloat(state.sphereScale))
            .shadow(
                color: state.palette.accent.color.opacity(0.25),
                radius: 32
            )
            .accessibilityHidden(true)
    }
}
