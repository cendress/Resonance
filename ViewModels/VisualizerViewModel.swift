import Foundation
import Observation

@MainActor
@Observable
final class VisualizerViewModel {
    private(set) var visualizerState: VisualizerState = .idle
    private(set) var latestMetrics: AudioMetrics = .silence
    private(set) var importedFileName: String?
    private(set) var songTitle: String?
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var isControlsPresented = false

    var hasImportedAudio: Bool {
        importedFileName != nil
    }

    var displayTitle: String? {
        songTitle ?? importedFileName
    }

    private let audioPipeline: AudioPipeline
    private var mappingEngine: VisualMappingEngine

    init() {
        let audioPipeline = AudioPipeline()
        self.audioPipeline = audioPipeline
        mappingEngine = VisualMappingEngine()
        configurePipeline()
    }

    init(audioPipeline: AudioPipeline) {
        self.audioPipeline = audioPipeline
        mappingEngine = VisualMappingEngine()
        configurePipeline()
    }

    func importAudio(from url: URL) async {
        isLoading = true
        errorMessage = nil

        do {
            if hasImportedAudio {
                try await audioPipeline.changeSong(to: url)
            } else {
                try await audioPipeline.load(from: url)
            }

            importedFileName = url.lastPathComponent
            songTitle = audioPipeline.displayTitle
            latestMetrics = .silence
            _ = mappingEngine.reset()

            do {
                try audioPipeline.play()
                isPlaying = true
            } catch {
                isPlaying = false
                errorMessage = error.localizedDescription
                settleTowardIdle(preservingPalette: true)
            }
        } catch {
            errorMessage = error.localizedDescription
            if !audioPipeline.isLoaded {
                importedFileName = nil
                songTitle = nil
                isPlaying = false
                settleTowardIdle(preservingPalette: false)
            }
        }

        isLoading = false
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard hasImportedAudio else { return }
        do {
            try audioPipeline.play()
            isPlaying = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            isPlaying = false
        }
    }

    func pause() {
        audioPipeline.pause()
        isPlaying = false
        latestMetrics = .silence
        settleTowardIdle(preservingPalette: true)
    }

    func stop() {
        audioPipeline.stop()
        isPlaying = false
        latestMetrics = .silence
        settleTowardIdle(preservingPalette: true)
    }

    func removeSong() {
        audioPipeline.removeSong()
        importedFileName = nil
        songTitle = nil
        isPlaying = false
        latestMetrics = .silence
        _ = mappingEngine.reset()
        settleTowardIdle(preservingPalette: false)
    }

    func clearError() {
        errorMessage = nil
    }

    func reportError(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    func receive(_ metrics: AudioMetrics) {
        guard isPlaying else { return }
        latestMetrics = metrics
        visualizerState = mappingEngine.map(metrics)
    }

    private func configurePipeline() {
        audioPipeline.metricsHandler = { [weak self] metrics in
            self?.receive(metrics)
        }

        audioPipeline.playbackEndedHandler = { [weak self] in
            guard let self else { return }
            isPlaying = false
            latestMetrics = .silence
            settleTowardIdle(preservingPalette: true)
        }
    }

    private func settleTowardIdle(preservingPalette: Bool) {
        var calmState = VisualizerState.idle
        if preservingPalette {
            calmState.palette = visualizerState.palette
        }
        visualizerState = calmState
    }
}
