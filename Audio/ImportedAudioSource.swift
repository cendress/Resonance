@preconcurrency import AVFoundation
import Foundation

enum ImportedAudioSourceError: LocalizedError {
    case invalidAudioFormat
    case noSongLoaded

    var errorDescription: String? {
        switch self {
        case .invalidAudioFormat:
            "The selected file does not contain a playable PCM audio stream."
        case .noSongLoaded:
            "Import a song before starting playback."
        }
    }
}

/// Owns imported-file playback and exposes the exact played signal through a PCM tap.
@MainActor
final class ImportedAudioSource {
    typealias PCMHandler = @Sendable (AVAudioPCMBuffer) -> Void

    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()

    private(set) var url: URL?
    private(set) var displayTitle: String?
    private(set) var isPlaying = false
    private(set) var isPaused = false

    var playbackEndedHandler: (() -> Void)?

    private var audioFile: AVAudioFile?
    private var hasInstalledTap = false
    private var isScheduled = false
    private var isAccessingSecurityScopedResource = false
    private var playbackGeneration: UInt64 = 0

    init() {
        engine.attach(playerNode)
    }

    var isLoaded: Bool {
        audioFile != nil
    }

    func load(url: URL, analysisHandler: @escaping PCMHandler) async throws {
        removeSong()

        let gainedSecurityAccess = url.startAccessingSecurityScopedResource()
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            guard
                format.sampleRate > 0,
                format.channelCount > 0,
                format.commonFormat == .pcmFormatFloat32
            else {
                throw ImportedAudioSourceError.invalidAudioFormat
            }

            self.url = url
            audioFile = file
            isAccessingSecurityScopedResource = gainedSecurityAccess
            displayTitle = await Self.title(for: url) ?? url.deletingPathExtension().lastPathComponent

            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
            installTap(format: format, analysisHandler: analysisHandler)
            engine.prepare()
            scheduleFromBeginning()
        } catch {
            if gainedSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
            self.url = nil
            audioFile = nil
            displayTitle = nil
            throw error
        }
    }

    func play() throws {
        guard isLoaded else {
            throw ImportedAudioSourceError.noSongLoaded
        }

        if !isScheduled {
            scheduleFromBeginning()
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }

        playerNode.play()
        isPlaying = true
        isPaused = false
    }

    func pause() {
        guard isPlaying else { return }
        playerNode.pause()
        isPlaying = false
        isPaused = true
    }

    /// Stops playback and rewinds the loaded song so the next play starts at zero.
    func stop() {
        guard isLoaded else { return }
        playbackGeneration &+= 1
        playerNode.stop()
        engine.pause()
        isPlaying = false
        isPaused = false
        isScheduled = false
        scheduleFromBeginning()
    }

    func changeSong(to url: URL, analysisHandler: @escaping PCMHandler) async throws {
        try await load(url: url, analysisHandler: analysisHandler)
    }

    func removeSong() {
        playbackGeneration &+= 1
        playerNode.stop()
        engine.stop()
        isPlaying = false
        isPaused = false
        isScheduled = false

        if hasInstalledTap {
            playerNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }

        engine.disconnectNodeOutput(playerNode)
        audioFile = nil
        displayTitle = nil

        if isAccessingSecurityScopedResource, let url {
            url.stopAccessingSecurityScopedResource()
        }
        isAccessingSecurityScopedResource = false
        url = nil

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func installTap(
        format: AVAudioFormat,
        analysisHandler: @escaping PCMHandler
    ) {
        if hasInstalledTap {
            playerNode.removeTap(onBus: 0)
        }

        playerNode.installTap(
            onBus: 0,
            bufferSize: 2_048,
            format: format
        ) { buffer, _ in
            analysisHandler(buffer)
        }
        hasInstalledTap = true
    }

    private func scheduleFromBeginning() {
        guard let audioFile else { return }
        audioFile.framePosition = 0
        playbackGeneration &+= 1
        let generation = playbackGeneration
        isScheduled = true

        playerNode.scheduleFile(
            audioFile,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard
                    let self,
                    self.playbackGeneration == generation,
                    self.isScheduled
                else {
                    return
                }
                self.isScheduled = false
                self.isPlaying = false
                self.isPaused = false
                self.playbackEndedHandler?()
            }
        }
    }

    private static func title(for url: URL) async -> String? {
        let asset = AVURLAsset(url: url)
        guard let metadata = try? await asset.load(.commonMetadata) else {
            return nil
        }

        for item in metadata where item.identifier == .commonIdentifierTitle {
            if let title = try? await item.load(.stringValue),
               !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return title
            }
        }
        return nil
    }
}
