import SwiftUI
import UniformTypeIdentifiers

struct ControlsSheet: View {
    @Bindable var viewModel: VisualizerViewModel
    @State private var isFileImporterPresented = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Audio") {
                    LabeledContent(
                        "Song",
                        value: viewModel.displayTitle ?? "None"
                    )

                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Label(
                            viewModel.hasImportedAudio ? "Change Song" : "Import Song",
                            systemImage: "square.and.arrow.down"
                        )
                    }
                    .disabled(viewModel.isLoading)

                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                        }
                    }

                    HStack {
                        Button(viewModel.isPlaying ? "Pause" : "Play") {
                            viewModel.togglePlayback()
                        }
                        .disabled(!viewModel.hasImportedAudio || viewModel.isLoading)

                        Button("Stop") {
                            viewModel.stop()
                        }
                        .disabled(!viewModel.hasImportedAudio)
                    }

                    Button("Remove Song", role: .destructive) {
                        viewModel.removeSong()
                    }
                    .disabled(!viewModel.hasImportedAudio)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Visualizer")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await viewModel.importAudio(from: url)
                }
            case .failure(let error):
                // Cancellation is reported by the importer and needs no persistent UI state.
                if (error as NSError).code != NSUserCancelledError {
                    Task { @MainActor in
                        viewModel.reportError(error)
                    }
                }
            }
        }
    }
}
