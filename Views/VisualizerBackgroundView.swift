import SwiftUI

/// A temporary background that depends only on mapped visualizer state.
struct VisualizerBackgroundView: View {
    let state: VisualizerState

    var body: some View {
        LinearGradient(
            colors: [
                state.palette.primary.color,
                state.palette.secondary.color,
                .black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .opacity(0.72 + Double(state.backgroundBrightness * 0.28))
        .accessibilityHidden(true)
    }
}
