import SwiftUI
import UniformTypeIdentifiers

struct ControlsSheet: View {
    @Bindable var viewModel: VisualizerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isFileImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            songSummary

            if viewModel.hasImportedAudio {
                loadedSongControls
            } else {
                importButton
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 26)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .animation(.smooth(duration: 0.28), value: viewModel.hasImportedAudio)
        .animation(.smooth(duration: 0.22), value: viewModel.isPlaying)
        .animation(.smooth(duration: 0.22), value: viewModel.errorMessage)
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

    private var header: some View {
        HStack {
            Text("Controls")
                .font(.title3.weight(.semibold))

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glass(.clear.interactive()))
            .buttonBorderShape(.circle)
            .accessibilityLabel("Close controls")
        }
    }

    private var songSummary: some View {
        HStack(spacing: 14) {
            Image(systemName: viewModel.hasImportedAudio ? "waveform" : "music.note")
                .font(.system(size: 19, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.hasImportedAudio ? "CURRENT SONG" : "NO SONG LOADED")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)

                Text(viewModel.displayTitle ?? "Import audio to begin")
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if viewModel.isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.footnote)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Playing")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.10), lineWidth: 0.5)
        }
    }

    private var loadedSongControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    viewModel.togglePlayback()
                } label: {
                    Label(
                        viewModel.isPlaying ? "Pause" : "Play",
                        systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(viewModel.isLoading)

                Button {
                    isFileImporterPresented = true
                } label: {
                    Label("Change", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .disabled(viewModel.isLoading)
            }
            .controlSize(.large)

            Button(role: .destructive) {
                viewModel.removeSong()
            } label: {
                Label("Remove Song", systemImage: "trash")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass(.clear.interactive()))
            .tint(.red.opacity(0.82))
            .disabled(viewModel.isLoading)
        }
    }

    private var importButton: some View {
        Button {
            isFileImporterPresented = true
        } label: {
            Label("Import Song", systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(viewModel.isLoading)
    }
}

#Preview("Controls Sheet") {
    ControlsSheet(viewModel: VisualizerViewModel())
        .preferredColorScheme(.dark)
}
