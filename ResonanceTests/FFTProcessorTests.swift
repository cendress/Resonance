@preconcurrency import AVFoundation
import Foundation
import Testing
@testable import Resonance

struct FFTProcessorTests {
    private let sampleRate = 44_100.0
    private let fftSize = 4_096

    @Test
    func generatedSineWavesLandInExpectedFrequencyRegions() {
        let cases: [(frequency: Float, band: AudioFrequencyBand)] = [
            (50, AudioFrequencyBands.subBass),
            (120, AudioFrequencyBands.bass),
            (350, AudioFrequencyBands.lowMids),
            (1_000, AudioFrequencyBands.mids),
            (3_000, AudioFrequencyBands.upperMids),
            (8_000, AudioFrequencyBands.treble)
        ]

        for testCase in cases {
            let processor = FFTProcessor(size: fftSize)
            let samples = sineWave(frequency: testCase.frequency)
            samples.withUnsafeBufferPointer {
                processor.process(samples: $0, sampleRate: sampleRate)
            }

            let dominantFrequency = processor.dominantFrequency()
            let expectedMagnitude = processor.peakMagnitude(
                in: testCase.band.frequencies
            )
            let strongestOtherBand = AudioFrequencyBands.all
                .filter { $0 != testCase.band }
                .map { processor.peakMagnitude(in: $0.frequencies) }
                .max() ?? 0

            #expect(testCase.band.frequencies.contains(dominantFrequency))
            #expect(expectedMagnitude > strongestOtherBand * 3)
        }
    }

    @Test
    func silenceProducesNoSpectralEnergy() {
        let processor = FFTProcessor(size: fftSize)
        let samples = Array(repeating: Float.zero, count: fftSize)

        samples.withUnsafeBufferPointer {
            processor.process(samples: $0, sampleRate: sampleRate)
        }

        #expect(processor.rms == 0)
        #expect(processor.dominantFrequency() == 0)
        #expect(AudioFrequencyBands.all.allSatisfy {
            processor.peakMagnitude(in: $0.frequencies) == 0
        })
    }

    @Test
    func analyzerAndVisualBassMappingPreserveQuietResponseAndHeadroom() {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )!
        var rawBassReadings: [Float] = []
        var visualBassReadings: [Float] = []

        for amplitude: Float in [0, 0.003, 0.01, 0.02, 0.04, 0.08, 0.18] {
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(2_048)
            )!
            buffer.frameLength = AVAudioFrameCount(2_048)
            let samples = buffer.floatChannelData![0]
            for frame in 0..<2_048 {
                let phase = Float(frame) / Float(sampleRate)
                samples[frame] = amplitude * sin(2 * .pi * 110 * phase)
                    + (amplitude * 0.28) * sin(2 * .pi * 55 * phase)
                    + 0.006 * sin(2 * .pi * 900 * phase)
            }

            let analyzer = AudioAnalyzer()
            let metrics = analyzer.analyze(buffer)
            var mapping = VisualMappingEngine()
            var state = VisualizerState.idle
            for _ in 0..<6 {
                state = mapping.map(metrics)
            }
            rawBassReadings.append(metrics.bass)
            visualBassReadings.append(state.visualBass)
            #expect(abs(mapping.visualBassMapper.lastRawBass
                - ((metrics.subBass * 0.35) + (metrics.bass * 0.65))) < 0.0001)
        }

        #expect(rawBassReadings[0] == 0)
        #expect(visualBassReadings[0] == 0)
        #expect(rawBassReadings[1] > 0.30)
        #expect(rawBassReadings[3] > rawBassReadings[1])
        #expect(rawBassReadings[5] > rawBassReadings[3])
        #expect(visualBassReadings[1] > 0.65)
        #expect(visualBassReadings[3] > visualBassReadings[1])
        #expect(visualBassReadings[5] > visualBassReadings[3])
        #expect(visualBassReadings[3] < 1)
    }

    private func sineWave(frequency: Float, amplitude: Float = 0.8) -> [Float] {
        (0..<fftSize).map { sample in
            amplitude * sin(
                2 * Float.pi * frequency * Float(sample) / Float(sampleRate)
            )
        }
    }
}
