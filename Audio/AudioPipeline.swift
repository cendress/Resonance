@preconcurrency import AVFoundation
import Foundation
import os

/// A lock-protected single-value mailbox between the realtime tap and the main actor.
nonisolated final class AudioMetricsMailbox: @unchecked Sendable {
    private struct State {
        var metrics = AudioMetrics.silence
        var sequence: UInt64 = 0
    }

    private let storage = OSAllocatedUnfairLock(initialState: State())

    func publish(_ metrics: AudioMetrics) {
        storage.withLock { state in
            state.metrics = metrics
            state.sequence &+= 1
        }
    }

    func latest(after sequence: UInt64) -> (metrics: AudioMetrics, sequence: UInt64)? {
        storage.withLock { state in
            guard state.sequence != sequence else { return nil }
            return (state.metrics, state.sequence)
        }
    }

    func reset() {
        storage.withLock { state in
            state.metrics = .silence
            state.sequence &+= 1
        }
    }
}

/// Coordinates imported playback, realtime DSP, and bounded main-actor metric delivery.
@MainActor
final class AudioPipeline {
    typealias MetricsHandler = @MainActor (AudioMetrics) -> Void

    var metricsHandler: MetricsHandler?
    var playbackEndedHandler: (() -> Void)?

    private(set) var source: ImportedAudioSource
    private let analyzer: AudioAnalyzer
    private let mailbox = AudioMetricsMailbox()
    private var deliveryTask: Task<Void, Never>?
    private var deliveredSequence: UInt64 = 0

    init() {
        source = ImportedAudioSource()
        analyzer = AudioAnalyzer()
        configureCallbacks()
        startMetricsDelivery()
    }

    init(analyzer: AudioAnalyzer) {
        source = ImportedAudioSource()
        self.analyzer = analyzer
        configureCallbacks()
        startMetricsDelivery()
    }

    deinit {
        deliveryTask?.cancel()
    }

    var isLoaded: Bool {
        source.isLoaded
    }

    var isPlaying: Bool {
        source.isPlaying
    }

    var displayTitle: String? {
        source.displayTitle
    }

    func load(from url: URL) async throws {
        source.stop()
        analyzer.reset()
        mailbox.reset()

        let analyzer = analyzer
        let mailbox = mailbox
        try await source.load(url: url) { buffer in
            mailbox.publish(analyzer.analyze(buffer))
        }
    }

    func play() throws {
        try source.play()
    }

    func pause() {
        source.pause()
        analyzer.reset()
        mailbox.reset()
    }

    func stop() {
        source.stop()
        analyzer.reset()
        mailbox.reset()
    }

    func changeSong(to url: URL) async throws {
        analyzer.reset()
        mailbox.reset()

        let analyzer = analyzer
        let mailbox = mailbox
        try await source.changeSong(to: url) { buffer in
            mailbox.publish(analyzer.analyze(buffer))
        }
    }

    func removeSong() {
        source.removeSong()
        analyzer.reset()
        mailbox.reset()
    }

    private func configureCallbacks() {
        source.playbackEndedHandler = { [weak self] in
            self?.mailbox.reset()
            self?.playbackEndedHandler?()
        }
    }

    private func startMetricsDelivery() {
        deliveryTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                guard let self else { return }

                if let update = mailbox.latest(after: deliveredSequence) {
                    deliveredSequence = update.sequence
                    metricsHandler?(update.metrics)
                }
            }
        }
    }
}
