import SwiftUI

struct VisualizerView: View {
    @Bindable var viewModel: VisualizerViewModel

    var body: some View {
        ZStack {
            VisualizerSurface(viewModel: viewModel)

            VStack {
                Spacer()

                HStack {
                    Spacer()

                    VisualizerControlsButton(
                        isPresented: $viewModel.isControlsPresented
                    )
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $viewModel.isControlsPresented) {
            ControlsSheet(viewModel: viewModel)
                .presentationDetents([
                    .height(viewModel.hasImportedAudio ? 390 : 310)
                ])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(34)
                .presentationBackground(.ultraThinMaterial)
        }
        .preferredColorScheme(.dark)
    }
}

private struct VisualizerSurface: View {
    @Bindable var viewModel: VisualizerViewModel

    var body: some View {
        ZStack {
            VisualizerBackgroundView(state: viewModel.visualizerState)
                .ignoresSafeArea()

            SphereView(state: viewModel.visualizerState)
        }
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
