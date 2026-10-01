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
        let idleStart = geometry.vertices.enumerated().map {
            SphereMotion.deformedVertex($0.element, index: $0.offset, time: 0, state: .idle)
        }
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

        #expect(idleStart != idle)
        #expect(idle != reactive)
        #expect((idle + reactive).allSatisfy {
            let radius = simd_length($0)
            return radius.isFinite && (0.90...1.14).contains(radius)
        })
        #expect(zip(geometry.vertices, reactive).allSatisfy { pair in
            simd_length(simd_cross(pair.0, simd_normalize(pair.1))) < 0.0001
        })
    }

    @Test
    func rotationRemainsAmbientUnderEnergeticAudio() {
        var quietEngine = VisualMappingEngine()
        var energeticEngine = VisualMappingEngine()
        let quietMetrics = AudioMetrics(loudness: 0.08, energy: 0.08)
        let energeticMetrics = AudioMetrics(
            subBass: 0.8,
            bass: 0.9,
            lowMids: 0.8,
            mids: 0.7,
            treble: 0.6,
            loudness: 0.9,
            energy: 1,
            beatPulse: 1
        )

        var quiet = VisualizerState.idle
        var energetic = VisualizerState.idle
        for _ in 0..<120 {
            quiet = quietEngine.map(quietMetrics)
            energetic = energeticEngine.map(energeticMetrics)
        }

        let slowestRate = (2 * Float.pi) / 60
        let fastestRate = (2 * Float.pi) / 30
        #expect((slowestRate...fastestRate).contains(quiet.rotationRate))
        #expect((slowestRate...fastestRate).contains(energetic.rotationRate))
        #expect(abs(energetic.rotationRate - quiet.rotationRate) < 0.0031)

        let oneAmbientTurn = SphereMotion.orientation(at: 48, state: .idle).y
            - SphereMotion.orientation(at: 0, state: .idle).y
        #expect(abs(oneAmbientTurn - (2 * Float.pi)) < 0.001)
    }

    @Test
    func bassBreathesBroadlyAndLowMidsCreateTravelingWaves() {
        let geometry = IcosphereGeometry.visualizer
        var bassState = VisualizerState.idle
        bassState.bass = 1
        bassState.energy = 1

        var lowMidState = VisualizerState.idle
        lowMidState.lowMids = 1
        lowMidState.energy = 1
        lowMidState.surfaceDisplacement = 1

        let idleRadii = radii(for: geometry, state: .idle, time: 1)
        let bassRadii = radii(for: geometry, state: bassState, time: 1)
        let lowMidRadii = radii(for: geometry, state: lowMidState, time: 1)
        let idleMean = idleRadii.reduce(0, +) / Float(idleRadii.count)
        let bassMean = bassRadii.reduce(0, +) / Float(bassRadii.count)

        #expect(bassMean > idleMean + 0.02)
        #expect((lowMidRadii.max()! - lowMidRadii.min()!) > 0.06)
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

    private func radii(
        for geometry: IcosphereGeometry,
        state: VisualizerState,
        time: Float
    ) -> [Float] {
        geometry.vertices.enumerated().map {
            simd_length(
                SphereMotion.deformedVertex(
                    $0.element,
                    index: $0.offset,
                    time: time,
                    state: state
                )
            )
        }
    }
}
