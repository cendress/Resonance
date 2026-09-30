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
