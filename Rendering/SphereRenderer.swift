import SwiftUI
import simd

/// Canvas renderer backed by reusable buffers and immutable cached topology.
/// Its only dynamic input is `VisualizerState`.
@MainActor
final class SphereRenderer {
    private let geometry: IcosphereGeometry
    private var transformedVertices: [SIMD3<Float>]
    private var projectedVertices: [ProjectedSpherePoint]
    private var faceDepths: [Float]
    private var faceOrder: [Int]
    private var springSystem = SphereSpringSystem()
    private var previousRenderTime: Float?

    init(geometry providedGeometry: IcosphereGeometry? = nil) {
        let geometry = providedGeometry ?? .visualizer
        self.geometry = geometry
        transformedVertices = Array(repeating: .zero, count: geometry.vertices.count)
        projectedVertices = Array(
            repeating: ProjectedSpherePoint(position: .zero, depth: 0, perspectiveScale: 1),
            count: geometry.vertices.count
        )
        faceDepths = Array(repeating: 0, count: geometry.faces.count)
        faceOrder = Array(geometry.faces.indices)
    }

    func render(
        into context: inout GraphicsContext,
        size: CGSize,
        state: VisualizerState,
        palette: VisualizerPalette,
        time: Float
    ) {
        guard size.width > 0, size.height > 0 else { return }

        let orientation = SphereMotion.orientation(at: time, state: state)
        let deltaTime: Float
        if let previousRenderTime, time >= previousRenderTime {
            deltaTime = time - previousRenderTime
        } else {
            springSystem.reset()
            deltaTime = 1 / 60
        }
        previousRenderTime = time
        let motionResponse = springSystem.update(
            state: state,
            time: time,
            deltaTime: deltaTime
        )
        let center = SIMD2<Float>(Float(size.width * 0.5), Float(size.height * 0.46))
        let screenRadius = Float(min(size.width, size.height)) * 0.335
        let overallScale = SphereMath.clamp(state.sphereScale, lowerBound: 0.86, upperBound: 1.24)

        for index in geometry.vertices.indices {
            let deformed = SphereMotion.deformedVertex(
                geometry.vertices[index],
                index: index,
                time: time,
                state: state,
                response: motionResponse
            ) * overallScale
            let transformed = SphereMath.rotate(deformed, angles: orientation)
            transformedVertices[index] = transformed

            let projected = SphereMath.project(transformed)
            projectedVertices[index] = ProjectedSpherePoint(
                position: center + SIMD2<Float>(
                    projected.position.x * screenRadius,
                    -projected.position.y * screenRadius
                ),
                depth: projected.depth,
                perspectiveScale: projected.perspectiveScale
            )
        }

        for index in geometry.faces.indices {
            let face = geometry.faces[index]
            faceDepths[index] = (
                transformedVertices[Int(face.a)].z
                    + transformedVertices[Int(face.b)].z
                    + transformedVertices[Int(face.c)].z
            ) / 3
        }
        let depths = faceDepths
        faceOrder.sort { depths[$0] < depths[$1] }

        drawGlow(
            into: &context,
            center: center,
            radius: screenRadius * overallScale,
            state: state,
            palette: palette
        )

        let lightDirection = SphereMath.normalize(SIMD3<Float>(-0.28, 0.34, 1))
        for faceIndex in faceOrder {
            let face = geometry.faces[faceIndex]
            let firstIndex = Int(face.a)
            let secondIndex = Int(face.b)
            let thirdIndex = Int(face.c)

            let normal = SphereMath.faceNormal(
                transformedVertices[firstIndex],
                transformedVertices[secondIndex],
                transformedVertices[thirdIndex]
            )
            let frontFacing = SphereMath.clamp((normal.z + 1) * 0.5)
            let illumination = SphereMath.clamp((simd_dot(normal, lightDirection) + 1) * 0.5)
            let depth = SphereMath.clamp((faceDepths[faceIndex] + 1.35) / 2.7)

            let first = projectedVertices[firstIndex].position
            let second = projectedVertices[secondIndex].position
            let third = projectedVertices[thirdIndex].position
            var path = Path()
            path.move(to: CGPoint(x: CGFloat(first.x), y: CGFloat(first.y)))
            path.addLine(to: CGPoint(x: CGFloat(second.x), y: CGFloat(second.y)))
            path.addLine(to: CGPoint(x: CGFloat(third.x), y: CGFloat(third.y)))
            path.closeSubpath()

            let faceSeed = Float((faceIndex * 37) % 101) / 100
            var fillColor = palette.shadow.mixed(
                with: palette.rich,
                amount: 0.18 + (faceSeed * 0.28) + (state.energy * 0.12)
            )
            fillColor = fillColor.mixed(
                with: palette.soft,
                amount: frontFacing * illumination * (0.30 + (state.loudness * 0.18))
            )

            let fillOpacity = 0.025
                + (frontFacing * 0.20)
                + (depth * 0.055)
                + (state.loudness * frontFacing * 0.08)
            context.fill(
                path,
                with: .color(fillColor.color.opacity(Double(fillOpacity)))
            )

            let lineColor = palette.accent.mixed(
                with: palette.light,
                amount: illumination * frontFacing
            )
            let lineOpacity = 0.055
                + (frontFacing * 0.37)
                + (depth * 0.08)
                + (state.beatPulse * frontFacing * 0.10)
            let lineWidth = CGFloat(0.32 + (frontFacing * 0.66) + (state.energy * 0.14))
            context.stroke(
                path,
                with: .color(lineColor.color.opacity(Double(lineOpacity))),
                lineWidth: lineWidth
            )
        }
    }

    private func drawGlow(
        into context: inout GraphicsContext,
        center: SIMD2<Float>,
        radius: Float,
        state: VisualizerState,
        palette: VisualizerPalette
    ) {
        let glowRadius = CGFloat(radius * (1.72 + (state.beatPulse * 0.12)))
        let rect = CGRect(
            x: CGFloat(center.x) - glowRadius,
            y: CGFloat(center.y) - glowRadius,
            width: glowRadius * 2,
            height: glowRadius * 2
        )
        context.drawLayer { glowContext in
            glowContext.addFilter(.blur(radius: 32))
            glowContext.opacity = 0.07 + Double(state.loudness * 0.09)
            glowContext.fill(Path(ellipseIn: rect), with: .color(palette.accent.color))
        }
    }
}
