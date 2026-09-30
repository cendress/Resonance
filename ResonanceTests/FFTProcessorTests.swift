import AVFoundation
import Testing
@testable import Resonance

struct FFTProcessorTests {
    @Test
    func placeholderReturnsExpectedBinCount() throws {
        let processor = FFTProcessor(size: 1_024)
        let format = try #require(
            AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        )
        let buffer = try #require(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1_024)
        )

        let magnitudes = processor.magnitudes(from: buffer)

        #expect(magnitudes.count == 512)
        #expect(magnitudes.allSatisfy { $0 == 0 })
    }
}
