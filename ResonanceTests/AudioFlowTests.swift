@preconcurrency import AVFoundation
import Foundation
import Testing
@testable import Resonance

@MainActor
struct AudioFlowTests {
    @Test
    func importPlayPauseResumeChangeAndRemove() async throws {
        let firstURL = try makeAudioFile(named: "First", frequency: 110)
        let secondURL = try makeAudioFile(named: "Second", frequency: 440)
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        let viewModel = VisualizerViewModel(audioPipeline: AudioPipeline())

        await viewModel.importAudio(from: firstURL)
        #expect(viewModel.hasImportedAudio)
        #expect(viewModel.isPlaying)
        #expect(viewModel.importedFileName == firstURL.lastPathComponent)

        viewModel.pause()
        #expect(!viewModel.isPlaying)
        #expect(viewModel.visualizerState.palette.family == .violet)

        viewModel.play()
        #expect(viewModel.isPlaying)

        await viewModel.importAudio(from: secondURL)
        #expect(viewModel.hasImportedAudio)
        #expect(viewModel.isPlaying)
        #expect(viewModel.importedFileName == secondURL.lastPathComponent)

        viewModel.removeSong()
        #expect(!viewModel.hasImportedAudio)
        #expect(!viewModel.isPlaying)
        #expect(viewModel.displayTitle == nil)
        #expect(viewModel.visualizerState == .idle)
    }

    private func makeAudioFile(named name: String, frequency: Float) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString).wav")
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate * 2)
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )!
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        )!
        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            samples[frame] = 0.18 * sin(
                2 * Float.pi * frequency * Float(frame) / Float(sampleRate)
            )
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}
