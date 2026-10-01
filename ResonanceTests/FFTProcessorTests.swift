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

    private func sineWave(frequency: Float, amplitude: Float = 0.8) -> [Float] {
        (0..<fftSize).map { sample in
            amplitude * sin(
                2 * Float.pi * frequency * Float(sample) / Float(sampleRate)
            )
        }
    }
}
