@preconcurrency import AVFoundation
import Foundation
import os

nonisolated struct AudioFrequencyBand: Equatable, Sendable {
    let name: String
    let frequencies: ClosedRange<Float>
}

/// Centralized, tunable frequency definitions for the visualizer.
nonisolated enum AudioFrequencyBands {
    static let subBass = AudioFrequencyBand(name: "Sub-bass", frequencies: 20...60)
    static let bass = AudioFrequencyBand(name: "Bass", frequencies: 60...250)
    static let lowMids = AudioFrequencyBand(name: "Low mids", frequencies: 250...500)
    static let mids = AudioFrequencyBand(name: "Mids", frequencies: 500...2_000)
    static let upperMids = AudioFrequencyBand(name: "Upper mids", frequencies: 2_000...4_000)
    static let treble = AudioFrequencyBand(name: "Treble", frequencies: 4_000...20_000)

    static let all: [AudioFrequencyBand] = [
        subBass,
        bass,
        lowMids,
        mids,
        upperMids,
        treble
    ]
}

/// Converts PCM windows into normalized musical metrics using Accelerate-backed FFT data.
nonisolated final class AudioAnalyzer: @unchecked Sendable {
    let fftProcessor: FFTProcessor
    private var transientDetector = TransientDetector()
    private let processingLock = OSAllocatedUnfairLock(initialState: ())

    init(fftSize: Int = 2_048) {
        fftProcessor = FFTProcessor(size: fftSize)
    }

    func analyze(_ buffer: AVAudioPCMBuffer) -> AudioMetrics {
        processingLock.withLock { _ in
            guard fftProcessor.process(buffer) else { return .silence }

            let loudness = Self.decibelNormalized(
                amplitude: fftProcessor.rms,
                floor: -62,
                ceiling: -5
            )
            let energy = min(max(pow(fftProcessor.rms * 2.8, 0.58), 0), 1)
            let beatPulse = transientDetector.detect(energy: energy)

            return AudioMetrics(
                subBass: normalizedBand(AudioFrequencyBands.subBass),
                bass: normalizedBand(AudioFrequencyBands.bass),
                lowMids: normalizedBand(AudioFrequencyBands.lowMids),
                mids: normalizedBand(AudioFrequencyBands.mids),
                upperMids: normalizedBand(AudioFrequencyBands.upperMids),
                treble: normalizedBand(AudioFrequencyBands.treble),
                loudness: loudness,
                energy: energy,
                brightness: fftProcessor.normalizedSpectralCentroid(),
                beatPulse: beatPulse
            )
        }
    }

    func reset() {
        processingLock.withLock { _ in
            transientDetector.reset()
        }
    }

    private func normalizedBand(_ band: AudioFrequencyBand) -> Float {
        let amplitude = fftProcessor.rootMeanSquareMagnitude(in: band.frequencies)
        return Self.decibelNormalized(amplitude: amplitude, floor: -78, ceiling: -18)
    }

    private static func decibelNormalized(
        amplitude: Float,
        floor: Float,
        ceiling: Float
    ) -> Float {
        guard amplitude > 0, ceiling > floor else { return 0 }
        let decibels = 20 * log10(max(amplitude, 0.000_000_1))
        return min(max((decibels - floor) / (ceiling - floor), 0), 1)
    }
}
