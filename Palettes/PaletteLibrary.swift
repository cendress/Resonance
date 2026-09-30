import Foundation

enum PaletteLibrary {
    static let midnight = VisualizerPalette(
        name: "Midnight",
        primary: VisualizerColor(red: 0.10, green: 0.16, blue: 0.30),
        secondary: VisualizerColor(red: 0.24, green: 0.15, blue: 0.42),
        accent: VisualizerColor(red: 0.42, green: 0.72, blue: 0.94)
    )

    static let ember = VisualizerPalette(
        name: "Ember",
        primary: VisualizerColor(red: 0.32, green: 0.08, blue: 0.12),
        secondary: VisualizerColor(red: 0.70, green: 0.22, blue: 0.10),
        accent: VisualizerColor(red: 1.00, green: 0.68, blue: 0.28)
    )

    static let aurora = VisualizerPalette(
        name: "Aurora",
        primary: VisualizerColor(red: 0.05, green: 0.28, blue: 0.26),
        secondary: VisualizerColor(red: 0.12, green: 0.45, blue: 0.52),
        accent: VisualizerColor(red: 0.56, green: 0.92, blue: 0.70)
    )
}
