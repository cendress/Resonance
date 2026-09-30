import Foundation
import Observation

@MainActor
@Observable
final class VisualizerViewModel {
    private(set) var visualizerState: VisualizerState = .idle
    private(set) var latestMetrics: AudioMetrics = .silence
    private(set) var importedFileName: String?
    private(set) var isPlaying = false
    var isControlsPresented = false

    var hasImportedAudio: Bool {
        importedFileName != nil
    }

    private let audioPipeline: AudioPipeline
    private var mappingEngine: VisualMappingEngine

    init() {
        let audioPipeline = AudioPipeline()
        self.audioPipeline = audioPipeline
        mappingEngine = VisualMappingEngine()

        audioPipeline.metricsHandler = { [weak self] metrics in
            self?.receive(metrics)
        }
    }

    init(audioPipeline: AudioPipeline) {
        self.audioPipeline = audioPipeline
        mappingEngine = VisualMappingEngine()

        audioPipeline.metricsHandler = { [weak self] metrics in
            self?.receive(metrics)
        }
    }

    func importAudio(from url: URL) throws {
        try audioPipeline.importAudio(from: url)
        importedFileName = url.lastPathComponent
        isPlaying = false
        visualizerState = mappingEngine.reset()
    }

    func togglePlayback() {
        guard hasImportedAudio else { return }

        isPlaying.toggle()
        if isPlaying {
            audioPipeline.start()
        } else {
            audioPipeline.stop()
        }
    }

    func analyzeNextAudioBuffer() throws {
        _ = try audioPipeline.analyzeNextBuffer()
    }

    func receive(_ metrics: AudioMetrics) {
        latestMetrics = metrics
        visualizerState = mappingEngine.map(metrics)
    }

    func reset() {
        audioPipeline.stop()
        audioPipeline.rewind()
        latestMetrics = .silence
        visualizerState = mappingEngine.reset()
        isPlaying = false
    }
}
