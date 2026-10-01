import SwiftUI

struct VisualizerBackgroundView: View {
    /// Twenty percent of the viewport is rendered past every edge so the
    /// strongest background warp still samples live gradient pixels.
    static let overscanScale: CGFloat = 1.40
    static let maximumHorizontalWarp: CGFloat = 74
    static let maximumVerticalWarp: CGFloat = 96

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
            let distortion = Self.distortionAmplitude(for: renderedState)

            GeometryReader { geometry in
                let sourceSize = CGSize(
                    width: geometry.size.width * Self.overscanScale,
                    height: geometry.size.height * Self.overscanScale
                )

                MeshGradient(
                    width: MeshGradientModel.width,
                    height: MeshGradientModel.height,
                    points: meshModel.points(at: elapsed, state: renderedState),
                    colors: colors.map(\.color),
                    background: palette.nearBlack.color,
                    smoothsColors: true
                )
                .frame(width: sourceSize.width, height: sourceSize.height)
                .overlay {
                    palette.nearBlack.color
                        .opacity(0.07 + Double(renderedState.bass * 0.08))
                        .blendMode(.multiply)
                }
                .distortionEffect(
                    ShaderLibrary.resonanceBackgroundDistortion(
                        .float(elapsed),
                        .float(distortion),
                        .float(renderedState.energy),
                        .float(renderedState.bass),
                        .float(renderedState.mids),
                        .float(renderedState.treble),
                        .float(renderedState.beatPulse),
                        .float2(sourceSize),
                        .float2(
                            Self.maximumHorizontalWarp,
                            Self.maximumVerticalWarp
                        )
                    ),
                    maxSampleOffset: CGSize(
                        width: Self.maximumHorizontalWarp,
                        height: Self.maximumVerticalWarp
                    )
                )
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )
            }
            .clipped()
        }
        .onChange(of: state.palette) { _, newPalette in
            paletteTransition.retarget(
                to: newPalette,
                at: Date().timeIntervalSinceReferenceDate
            )
        }
        .accessibilityHidden(true)
    }

    static func distortionAmplitude(for state: VisualizerState) -> Float {
        9
            + (state.mids * 5)
            + (state.energy * 9)
            + (state.bass * 5)
            + (state.beatPulse * 3)
    }
}

#Preview("Background") {
    VisualizerBackgroundView(state: .audioReactivePreview)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
}
