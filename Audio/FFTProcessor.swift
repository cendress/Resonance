import AVFoundation
import Foundation

/// Defines the future FFT output shape while deliberately performing no DSP yet.
struct FFTProcessor {
    let size: Int

    var binCount: Int {
        size / 2
    }

    init(size: Int = 1_024) {
        precondition(size > 1 && size.isMultiple(of: 2), "FFT size must be a positive even number")
        self.size = size
    }

    func magnitudes(from buffer: AVAudioPCMBuffer) -> [Float] {
        _ = buffer
        return Array(repeating: 0, count: binCount)
    }
}
