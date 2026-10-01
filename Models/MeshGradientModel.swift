import Foundation
import simd

/// A compact 4×4 mesh with irregular topology, persistent ambient motion, and audio modulation.
struct MeshGradientModel: Equatable, Sendable {
    static let width = 4
    static let height = 4
    static let idleDisplacement: Float = 0.052
    static let reactiveMidsDisplacement: Float = 0.045
    static let reactiveEnergyDisplacement: Float = 0.030
    static let bassPressureDisplacement: Float = 0.110
    static let beatPressureDisplacement: Float = 0.035
    static let colorMigrationRate: Float = 0.12

    private static let basePoints: [SIMD2<Float>] = [
        SIMD2(0.00, 0.00), SIMD2(0.27, 0.00), SIMD2(0.72, 0.00), SIMD2(1.00, 0.00),
        SIMD2(0.00, 0.29), SIMD2(0.31, 0.34), SIMD2(0.69, 0.27), SIMD2(1.00, 0.36),
        SIMD2(0.00, 0.68), SIMD2(0.37, 0.61), SIMD2(0.76, 0.72), SIMD2(1.00, 0.64),
        SIMD2(0.00, 1.00), SIMD2(0.24, 1.00), SIMD2(0.66, 1.00), SIMD2(1.00, 1.00)
    ]

    /// Each layout keeps depth in the composition while moving the light and
    /// dark pools through different parts of the mesh. Smooth interpolation
    /// between layouts prevents any palette role from staying spatially fixed.
    private static let colorRoleLayouts = [
        [
            5, 2, 4, 6,
            6, 1, 0, 3,
            5, 0, 2, 4,
            6, 3, 1, 5
        ],
        [
            4, 6, 2, 5,
            5, 3, 1, 6,
            3, 2, 0, 5,
            6, 4, 3, 5
        ],
        [
            3, 1, 5, 6,
            6, 2, 4, 3,
            4, 5, 1, 2,
            5, 3, 6, 4
        ],
        [
            6, 4, 3, 5,
            4, 0, 2, 5,
            2, 1, 5, 6,
            5, 3, 4, 2
        ]
    ]

    func points(at time: Float, state: VisualizerState) -> [SIMD2<Float>] {
        var result = Self.basePoints
        let travelAmplitude = Self.idleDisplacement
            + (state.mids * Self.reactiveMidsDisplacement)
            + (state.energy * Self.reactiveEnergyDisplacement)
        let centerExpansion = (state.bass * Self.bassPressureDisplacement)
            + (state.beatPulse * Self.beatPressureDisplacement)

        for index in result.indices {
            let row = index / Self.width
            let column = index % Self.width
            let phaseX = (Float(index) * 1.37) + 0.31
            let phaseY = (Float(index) * 1.91) + 1.17
            let primaryXSpeed = 0.18 + (Float((index * 7) % 5) * 0.024)
            let secondaryXSpeed = 0.11 + (Float((index * 3) % 4) * 0.019)
            let primaryYSpeed = 0.16 + (Float((index * 5) % 6) * 0.021)
            let secondaryYSpeed = 0.09 + (Float((index * 11) % 5) * 0.017)
            let drift = SIMD2<Float>(
                (
                    sin((time * primaryXSpeed) + phaseX) * 0.68
                        + sin((time * secondaryXSpeed) - (phaseY * 0.73)) * 0.32
                ) * travelAmplitude,
                (
                    cos((time * primaryYSpeed) + phaseY) * 0.64
                        + sin((time * secondaryYSpeed) + (phaseX * 0.81)) * 0.36
                ) * travelAmplitude
            )

            if row > 0, row < Self.height - 1, column > 0, column < Self.width - 1 {
                let fromCenter = result[index] - SIMD2<Float>(repeating: 0.5)
                result[index] += drift + (fromCenter * centerExpansion)
                let xBounds: ClosedRange<Float> = column == 1 ? 0.14...0.47 : 0.53...0.87
                let yBounds: ClosedRange<Float> = row == 1 ? 0.13...0.48 : 0.52...0.87
                result[index].x = min(max(result[index].x, xBounds.lowerBound), xBounds.upperBound)
                result[index].y = min(max(result[index].y, yBounds.lowerBound), yBounds.upperBound)
            } else if row == 0 || row == Self.height - 1 {
                if column > 0, column < Self.width - 1 {
                    result[index].x += drift.x * 0.58
                    result[index].x = min(max(result[index].x, 0.12), 0.88)
                }
            } else if column == 0 || column == Self.width - 1 {
                result[index].y += drift.y * 0.58
                result[index].y = min(max(result[index].y, 0.12), 0.88)
            }
        }
        return result
    }

    func colors(
        palette: VisualizerPalette,
        at time: Float,
        state: VisualizerState
    ) -> [VisualizerColor] {
        let migrationPosition = max(time, 0) * Self.colorMigrationRate
        let layoutFloor = floor(migrationPosition)
        let firstLayoutIndex = Int(layoutFloor) % Self.colorRoleLayouts.count
        let secondLayoutIndex = (firstLayoutIndex + 1) % Self.colorRoleLayouts.count
        let rawProgress = migrationPosition - layoutFloor
        let migrationProgress = rawProgress * rawProgress * (3 - (2 * rawProgress))
        let firstLayout = Self.colorRoleLayouts[firstLayoutIndex]
        let secondLayout = Self.colorRoleLayouts[secondLayoutIndex]

        return firstLayout.indices.map { index in
            var color = palette.colors[firstLayout[index]].mixed(
                with: palette.colors[secondLayout[index]],
                amount: migrationProgress
            )

            let row = index / Self.width
            let column = index % Self.width
            let gridPosition = SIMD2<Float>(
                Float(column) / Float(Self.width - 1),
                Float(row) / Float(Self.height - 1)
            )
            let shadowCenter = SIMD2<Float>(
                0.50 + (sin((time * 0.16) + 0.4) * 0.24),
                0.50 + (cos((time * 0.13) + 1.1) * 0.22)
            )
            let shadowDistance = simd_length(gridPosition - shadowCenter)
            let shadowField = pow(max(1 - (shadowDistance / 0.64), 0), 1.45)
            color = color.mixed(
                with: palette.nearBlack,
                amount: shadowField
                    * (0.055 + (state.bass * 0.15) + (state.beatPulse * 0.035))
            )

            let lightCenter = SIMD2<Float>(
                0.50 + (cos((time * 0.11) + 2.7) * 0.34),
                0.50 + (sin((time * 0.14) + 4.2) * 0.30)
            )
            let lightDistance = simd_length(gridPosition - lightCenter)
            let lightField = pow(max(1 - (lightDistance / 0.52), 0), 1.7)
            color = color.mixed(
                with: palette.soft,
                amount: lightField * (0.035 + (state.energy * 0.045))
            )

            color = color.adjusted(
                saturation: 1 + (state.energy * 0.27),
                brightness: 0.95 + (state.backgroundBrightness * 0.11)
            )

            color = color.mixed(
                with: palette.light,
                amount: lightField * state.beatPulse * 0.045
            )
            return color
        }
    }
}
