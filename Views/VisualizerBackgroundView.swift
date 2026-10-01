import SwiftUI

struct VisualizerBackgroundView: View {
    let state: VisualizerState
    private let meshModel = MeshGradientModel()
    @State private var stateInterpolator: VisualStateInterpolator
    @State private var paletteTransition: PaletteTransition
    @State private var animationOrigin = Date()

    init(state: VisualizerState) {
        self.state = state
        _stateInterpolator = State(
            initialValue: VisualStateInterpolator(initialValue: state)
        )
        _paletteTransition = State(initialValue: PaletteTransition(palette: state.palette))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
            let elapsed = Float(timeline.date.timeIntervalSince(animationOrigin))
            let paletteTime = timeline.date.timeIntervalSinceReferenceDate
            let renderedState = stateInterpolator.value(toward: state, at: paletteTime)
            let palette = paletteTransition.value(at: paletteTime)
            let colors = meshModel.colors(
                palette: palette,
                at: elapsed,
                state: renderedState
            )
            let distortion = 9.0
                + (Double(renderedState.mids) * 5.0)
                + (Double(renderedState.energy) * 9.0)
                + (Double(renderedState.bass) * 5.0)
                + (Double(renderedState.beatPulse) * 3.0)

            MeshGradient(
                width: MeshGradientModel.width,
                height: MeshGradientModel.height,
                points: meshModel.points(at: elapsed, state: renderedState),
                colors: colors.map(\.color),
                background: palette.nearBlack.color,
                smoothsColors: true
            )
            .scaleEffect(1.065)
            .distortionEffect(
                ShaderLibrary.resonanceBackgroundDistortion(
                    .float(elapsed),
                    .float(Float(distortion)),
                    .float(renderedState.energy),
                    .float(renderedState.bass),
                    .float(renderedState.mids),
                    .float(renderedState.treble),
                    .float(renderedState.beatPulse)
                ),
                maxSampleOffset: CGSize(width: 44, height: 44)
            )
            .overlay {
                palette.nearBlack.color
                    .opacity(0.07 + Double(renderedState.bass * 0.08))
                    .blendMode(.multiply)
            }
        }
        .onChange(of: state.palette) { _, newPalette in
            paletteTransition.retarget(
                to: newPalette,
                at: Date().timeIntervalSinceReferenceDate
            )
        }
        .accessibilityHidden(true)
    }
}

#Preview("Background") {
    VisualizerBackgroundView(state: .audioReactivePreview)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
}
