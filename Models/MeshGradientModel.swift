import Foundation

/// Placeholder data model for a future mesh-gradient implementation.
struct MeshGradientModel: Equatable, Sendable {
    var intensity: Float
    var palette: VisualizerPalette

    static let idle = MeshGradientModel(
        intensity: 0,
        palette: PaletteLibrary.midnight
    )
}
