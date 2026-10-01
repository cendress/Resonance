import SwiftUI

struct VisualizerBackgroundView: View {
    let state: VisualizerState
    private let meshModel = MeshGradientModel()
    @State private var paletteTransition: PaletteTransition
    @State private var animationOrigin = Date()

    init(state: VisualizerState) {
        self.state = state
        _paletteTransition = State(initialValue: PaletteTransition(palette: state.palette))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
            let elapsed = Float(timeline.date.timeIntervalSince(animationOrigin))
            let paletteTime = timeline.date.timeIntervalSinceReferenceDate
            let palette = paletteTransition.value(at: paletteTime)
            let colors = meshModel.colors(palette: palette, at: elapsed, state: state)
            let distortion = 5.0
                + (Double(state.mids) * 7.0)
                + (Double(state.energy) * 5.0)
                + (Double(state.beatPulse) * 2.0)

            MeshGradient(
                width: MeshGradientModel.width,
                height: MeshGradientModel.height,
                points: meshModel.points(at: elapsed, state: state),
                colors: colors.map(\.color),
                background: palette.nearBlack.color,
                smoothsColors: true
            )
            .scaleEffect(1.065)
            .distortionEffect(
                ShaderLibrary.resonanceBackgroundDistortion(
                    .float(elapsed),
                    .float(Float(distortion)),
                    .float(state.energy),
                    .float(state.bass),
                    .float(state.mids),
                    .float(state.treble)
                ),
                maxSampleOffset: CGSize(width: 24, height: 24)
            )
            .overlay {
                palette.nearBlack.color
                    .opacity(0.07 + Double(state.bass * 0.08))
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
