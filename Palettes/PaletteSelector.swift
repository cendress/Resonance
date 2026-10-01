import Foundation

/// Stable, rolling-character palette selection with warm-up and hysteresis.
struct PaletteSelector {
    private var currentFamily: PaletteFamily = .violet
    private var candidateFamily: PaletteFamily = .violet
    private var candidateFrames = 0
    private var analyzedFrames = 0

    private let warmupFrames = 75
    private let requiredStableFrames = 100

    mutating func palette(for character: RollingMusicCharacter) -> VisualizerPalette {
        analyzedFrames += 1
        guard analyzedFrames >= warmupFrames else {
            return PaletteLibrary.palette(for: currentFamily)
        }

        let preferred = preferredFamily(for: character)
        if preferred == candidateFamily {
            candidateFrames += 1
        } else {
            candidateFamily = preferred
            candidateFrames = 1
        }

        if candidateFamily != currentFamily, candidateFrames >= requiredStableFrames {
            currentFamily = candidateFamily
            candidateFrames = 0
        }

        return PaletteLibrary.palette(for: currentFamily)
    }

    mutating func reset() {
        currentFamily = .violet
        candidateFamily = .violet
        candidateFrames = 0
        analyzedFrames = 0
    }

    private func preferredFamily(for character: RollingMusicCharacter) -> PaletteFamily {
        let energy = character.longTermEnergy
        let brightness = character.longTermBrightness
        let bass = character.longTermBassPresence
        let rhythm = character.longTermRhythmicActivity
        let intensity = character.rollingIntensity
        let dynamics = character.rollingDynamicRange

        let scores: [(PaletteFamily, Float)] = [
            (.violet, 0.34 + ((1 - abs(brightness - 0.48)) * 0.20) + (dynamics * 0.10)),
            (.orange, (bass * 0.36) + (energy * 0.29) + (intensity * 0.23) + (dynamics * 0.12)),
            (.blue, ((1 - energy) * 0.35) + ((1 - rhythm) * 0.22) + ((1 - intensity) * 0.25) + ((1 - brightness) * 0.18)),
            (.green, (dynamics * 0.31) + (rhythm * 0.20) + ((1 - abs(brightness - 0.43)) * 0.28) + ((1 - intensity) * 0.21)),
            (.red, (intensity * 0.35) + (energy * 0.28) + (rhythm * 0.25) + (dynamics * 0.12)),
            (.teal, (brightness * 0.38) + (dynamics * 0.20) + ((1 - intensity) * 0.19) + ((1 - bass) * 0.13) + (rhythm * 0.10))
        ]

        return scores.max(by: { $0.1 < $1.1 })?.0 ?? .violet
    }
}
