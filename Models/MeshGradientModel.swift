import Foundation

/// A compact 4×4 mesh with irregular topology, persistent ambient motion, and audio modulation.
struct MeshGradientModel: Equatable, Sendable {
    static let width = 4
    static let height = 4

    private static let basePoints: [SIMD2<Float>] = [
        SIMD2(0.00, 0.00), SIMD2(0.27, 0.00), SIMD2(0.72, 0.00), SIMD2(1.00, 0.00),
        SIMD2(0.00, 0.29), SIMD2(0.31, 0.34), SIMD2(0.69, 0.27), SIMD2(1.00, 0.36),
        SIMD2(0.00, 0.68), SIMD2(0.37, 0.61), SIMD2(0.76, 0.72), SIMD2(1.00, 0.64),
        SIMD2(0.00, 1.00), SIMD2(0.24, 1.00), SIMD2(0.66, 1.00), SIMD2(1.00, 1.00)
    ]

    /// Central cells are darkest; edge roles are light but deliberately asymmetric.
    private static let colorRoles = [
        5, 2, 4, 6,
        6, 1, 0, 3,
        5, 0, 2, 4,
        6, 3, 1, 5
    ]

    func points(at time: Float, state: VisualizerState) -> [SIMD2<Float>] {
        var result = Self.basePoints
        let ambientAmplitude: Float = 0.009
        let formAmplitude = (state.mids * 0.022) + (state.energy * 0.012)
        let centerExpansion = (state.bass * 0.040) + (state.beatPulse * 0.014)

        for index in result.indices {
            let row = index / Self.width
            let column = index % Self.width
            let phase = Float(index) * 0.73
            let drift = SIMD2<Float>(
                sin((time * 0.115) + phase) * (ambientAmplitude + formAmplitude),
                cos((time * 0.093) + (phase * 1.31)) * (ambientAmplitude + formAmplitude)
            )

            if row > 0, row < Self.height - 1, column > 0, column < Self.width - 1 {
                let fromCenter = result[index] - SIMD2<Float>(repeating: 0.5)
                result[index] += drift + (fromCenter * centerExpansion)
                result[index].x = min(max(result[index].x, 0.15), 0.86)
                result[index].y = min(max(result[index].y, 0.15), 0.86)
            } else if row == 0 || row == Self.height - 1 {
                if column > 0, column < Self.width - 1 {
                    result[index].x += drift.x * 0.65
                }
            } else if column == 0 || column == Self.width - 1 {
                result[index].y += drift.y * 0.65
            }
        }
        return result
    }

    func colors(
        palette: VisualizerPalette,
        at time: Float,
        state: VisualizerState
    ) -> [VisualizerColor] {
        Self.colorRoles.enumerated().map { index, role in
            let neighborRole = (role + 1 + (index % 2)) % palette.colors.count
            let migration = 0.045
                + (0.025 * (sin((time * 0.08) + (Float(index) * 0.61)) + 1))
                + (state.treble * 0.035)
            var color = palette.colors[role].mixed(
                with: palette.colors[neighborRole],
                amount: migration
            )

            let isCentral = index == 5 || index == 6 || index == 9 || index == 10
            if isCentral {
                color = color.mixed(
                    with: palette.nearBlack,
                    amount: 0.12 + (state.bass * 0.18)
                )
            }

            color = color.adjusted(
                saturation: 1 + (state.energy * 0.24),
                brightness: 0.94 + (state.backgroundBrightness * 0.10)
            )

            if !isCentral {
                color = color.mixed(
                    with: palette.light,
                    amount: state.beatPulse * 0.055
                )
            }
            return color
        }
    }
}
