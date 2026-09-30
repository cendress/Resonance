import AVFoundation
import Foundation

/// Placeholder analyzer boundary. Real normalization and DSP will be added later.
struct AudioAnalyzer {
    func analyze(_ buffer: AVAudioPCMBuffer) -> AudioMetrics {
        _ = buffer
        return .silence
    }
}
