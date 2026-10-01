import simd
import Testing
@testable import Resonance

@MainActor
struct RenderingTests {
    @Test
    func icosphereBuildsExpectedCachedTopology() {
        let base = IcosphereGeometry(subdivisions: 0)
        let rendered = IcosphereGeometry.visualizer

        #expect(base.vertices.count == 12)
        #expect(base.faces.count == 20)
        #expect(rendered.vertices.count == 162)
        #expect(rendered.faces.count == 320)
        #expect(rendered.indices.count == 960)
        #expect(rendered.vertices.allSatisfy { abs(simd_length($0) - 1) < 0.0001 })
    }

    @Test
    func idleAndReactiveMeshRemainValidAndAnimated() {
        let model = MeshGradientModel()
        let idleStart = model.points(at: 0, state: .idle)
        let idleLater = model.points(at: 2, state: .idle)
        let reactive = model.points(at: 2, state: .audioReactivePreview)
        let colors = model.colors(
            palette: PaletteLibrary.teal,
            at: 2,
            state: .audioReactivePreview
        )

        #expect(idleStart.count == 16)
        #expect(reactive.count == 16)
        #expect(colors.count == 16)
        #expect(idleStart != idleLater)
        #expect(idleLater != reactive)
        #expect(reactive.allSatisfy {
            $0.x.isFinite && $0.y.isFinite
                && (0...1).contains($0.x) && (0...1).contains($0.y)
        })
    }

    @Test
    func sphereMotionStaysOrganicButRecognizablySpherical() {
        let geometry = IcosphereGeometry.visualizer
        let idle = geometry.vertices.enumerated().map {
            SphereMotion.deformedVertex($0.element, index: $0.offset, time: 2, state: .idle)
        }
        let reactive = geometry.vertices.enumerated().map {
            SphereMotion.deformedVertex(
                $0.element,
                index: $0.offset,
                time: 2,
                state: .audioReactivePreview
            )
        }

        #expect(idle != reactive)
        #expect((idle + reactive).allSatisfy {
            let radius = simd_length($0)
            return radius.isFinite && (0.88...1.16).contains(radius)
        })
    }

    @Test
    func mappingProducesSmoothedAudioReactiveState() {
        var engine = VisualMappingEngine()
        let metrics = AudioMetrics(
            subBass: 0.6,
            bass: 0.8,
            lowMids: 0.55,
            mids: 0.48,
            upperMids: 0.4,
            treble: 0.32,
            loudness: 0.65,
            energy: 0.7,
            brightness: 0.45,
            beatPulse: 0.75
        )

        var state = VisualizerState.idle
        for _ in 0..<12 {
            state = engine.map(metrics)
        }

        #expect(state.bass > 0)
        #expect(state.energy > 0)
        #expect(state.beatPulse > 0)
        #expect(state.sphereScale > 1)
        #expect(state.backgroundEnergy > 0)
    }

    @Test
    func displayInterpolationWakesAndSettlesWithoutJumping() {
        let interpolator = VisualStateInterpolator(initialValue: .idle)
        _ = interpolator.value(toward: .idle, at: 0)

        let waking = interpolator.value(
            toward: .audioReactivePreview,
            at: 1.0 / 60.0
        )
        let settling = interpolator.value(
            toward: .idle,
            at: 2.0 / 60.0
        )

        #expect(waking.energy > 0)
        #expect(waking.energy < VisualizerState.audioReactivePreview.energy)
        #expect(settling.energy > 0)
        #expect(settling.energy < waking.energy)
    }
}
