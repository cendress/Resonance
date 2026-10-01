import Foundation

struct PaletteSelector {
    func palette(for character: RollingMusicCharacter) -> VisualizerPalette {
        if character.longTermBrightness > 0.58 {
            return PaletteLibrary.aurora
        }

        if character.longTermEnergy > 0.52 && character.longTermBassPresence > 0.44 {
            return PaletteLibrary.ember
        }

        return PaletteLibrary.midnight
    }
}
