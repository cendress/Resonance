import SwiftUI

struct VisualizerView: View {
    @Bindable var viewModel: VisualizerViewModel

    var body: some View {
        ZStack {
            VisualizerBackgroundView(state: viewModel.visualizerState)
                .ignoresSafeArea()

            SphereView(state: viewModel.visualizerState)

            VStack {
                Spacer()

                VisualizerControlsButton(
                    isPresented: $viewModel.isControlsPresented
                )
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $viewModel.isControlsPresented) {
            ControlsSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .preferredColorScheme(.dark)
    }
}

private struct VisualizerSurfacePreview: View {
    let state: VisualizerState

    var body: some View {
        ZStack {
            VisualizerBackgroundView(state: state)
            SphereView(state: state)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

#Preview("Visualizer") {
    VisualizerView(viewModel: VisualizerViewModel())
}

#Preview("Idle") {
    VisualizerSurfacePreview(state: .idle)
}

#Preview("Audio Reactive") {
    VisualizerSurfacePreview(state: .audioReactivePreview)
}
