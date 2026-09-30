import Foundation

struct PaletteSelector {
    func palette(for character: RollingMusicCharacter) -> VisualizerPalette {
        if character.brightness > 0.62 {
            return PaletteLibrary.aurora
        }

        if character.energy > 0.58 && character.bassPresence > 0.48 {
            return PaletteLibrary.ember
        }

        return PaletteLibrary.midnight
    }
}
