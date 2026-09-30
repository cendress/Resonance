import SwiftUI

struct ControlsSheet: View {
    @Bindable var viewModel: VisualizerViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Audio") {
                    LabeledContent(
                        "Imported file",
                        value: viewModel.importedFileName ?? "None"
                    )

                    Button(viewModel.isPlaying ? "Pause" : "Play") {
                        viewModel.togglePlayback()
                    }
                    .disabled(!viewModel.hasImportedAudio)
                }

                Section("Prototype") {
                    Text("Audio import, DSP, and final rendering controls will be connected in a later milestone.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Visualizer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
