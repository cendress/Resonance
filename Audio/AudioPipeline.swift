import AVFoundation
import Foundation

/// Coordinates imported PCM delivery and normalized analysis results.
@MainActor
final class AudioPipeline {
    typealias MetricsHandler = @MainActor (AudioMetrics) -> Void

    var metricsHandler: MetricsHandler?

    private(set) var source: ImportedAudioSource?
    private(set) var isRunning = false
    private let analyzer: AudioAnalyzer

    init() {
        analyzer = AudioAnalyzer()
    }

    init(analyzer: AudioAnalyzer) {
        self.analyzer = analyzer
    }

    func importAudio(from url: URL) throws {
        source = try ImportedAudioSource(url: url)
        isRunning = false
    }

    func start() {
        guard source != nil else { return }
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    @discardableResult
    func analyzeNextBuffer() throws -> AudioMetrics? {
        guard let buffer = try source?.readPCMBuffer() else {
            isRunning = false
            return nil
        }

        let metrics = analyzer.analyze(buffer)
        metricsHandler?(metrics)
        return metrics
    }

    func rewind() {
        source?.reset()
    }
}
