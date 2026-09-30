import AVFoundation
import Foundation

/// Reads an imported audio file as PCM buffers without exposing file details downstream.
final class ImportedAudioSource {
    let url: URL
    private let audioFile: AVAudioFile

    init(url: URL) throws {
        self.url = url
        audioFile = try AVAudioFile(forReading: url)
    }

    func readPCMBuffer(
        maximumFrameCount: AVAudioFrameCount = 4_096
    ) throws -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: maximumFrameCount
        ) else {
            return nil
        }

        try audioFile.read(into: buffer, frameCount: maximumFrameCount)
        return buffer.frameLength > 0 ? buffer : nil
    }

    func reset() {
        audioFile.framePosition = 0
    }
}
