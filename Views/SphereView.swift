import SwiftUI

struct SphereView: View {
    let state: VisualizerState
    @State private var renderer = SphereRenderer()
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

            Canvas(
                opaque: false,
                colorMode: .extendedLinear,
                rendersAsynchronously: false
            ) { context, size in
                renderer.render(
                    into: &context,
                    size: size,
                    state: renderedState,
                    palette: palette,
                    time: elapsed
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: state.palette) { _, newPalette in
            paletteTransition.retarget(
                to: newPalette,
                at: Date().timeIntervalSinceReferenceDate
            )
        }
        .accessibilityHidden(true)
    }
}

#Preview("Sphere") {
    ZStack {
        Color.black
        SphereView(state: .audioReactivePreview)
    }
    .ignoresSafeArea()
    .preferredColorScheme(.dark)
}
