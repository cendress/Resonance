import CoreGraphics
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
    func maximumBackgroundWarpStaysInsideOverscanAndSamplingBudget() {
        var maximumState = VisualizerState.idle
        maximumState.mids = 1
        maximumState.energy = 1
        maximumState.bass = 1
        maximumState.beatPulse = 1

        let narrowestSupportedPhoneWidth: CGFloat = 375
        let shortestSupportedPhoneHeight: CGFloat = 667
        let horizontalBleed = narrowestSupportedPhoneWidth
            * (VisualizerBackgroundView.overscanScale - 1)
            / 2
        let verticalBleed = shortestSupportedPhoneHeight
            * (VisualizerBackgroundView.overscanScale - 1)
            / 2

        #expect(VisualizerBackgroundView.distortionAmplitude(for: maximumState) == 31)
        #expect(horizontalBleed >= VisualizerBackgroundView.maximumHorizontalWarp)
        #expect(verticalBleed >= VisualizerBackgroundView.maximumVerticalWarp)
    }

    @Test
    func maximumAudioMotionKeepsMeshBoundaryClosed() {
        let model = MeshGradientModel()
        var maximumState = VisualizerState.audioReactivePreview
        maximumState.bass = 1
        maximumState.mids = 1
        maximumState.energy = 1
        maximumState.beatPulse = 1

        for time: Float in [0, 7, 19, 41] {
            let points = model.points(at: time, state: maximumState)

            #expect((0..<MeshGradientModel.width).allSatisfy { points[$0].y == 0 })
            #expect((12..<16).allSatisfy { points[$0].y == 1 })
            #expect((0..<MeshGradientModel.height).allSatisfy {
                points[$0 * MeshGradientModel.width].x == 0
            })
            #expect((0..<MeshGradientModel.height).allSatisfy {
                points[($0 * MeshGradientModel.width) + 3].x == 1
            })
        }
    }

    @Test
    func idleBackgroundClearlyReorganizesAcrossTenSeconds() {
        let model = MeshGradientModel()
        let startPoints = model.points(at: 0, state: .idle)
        let laterPoints = model.points(at: 10, state: .idle)
        let startColors = model.colors(
            palette: PaletteLibrary.violet,
            at: 0,
            state: .idle
        )
        let laterColors = model.colors(
            palette: PaletteLibrary.violet,
            at: 10,
            state: .idle
        )
        let averagePointTravel = zip(startPoints, laterPoints).reduce(Float.zero) {
            $0 + simd_length($1.0 - $1.1)
        } / Float(startPoints.count)
        let changedColorCount = zip(startColors, laterColors).filter { $0 != $1 }.count

        #expect(averagePointTravel > 0.025)
        #expect(changedColorCount >= 12)
    }

    @Test
    func audioAmplifiesMeshTravelWithoutChangingItsClock() {
        let model = MeshGradientModel()
        let idleStart = model.points(at: 2, state: .idle)
        let idleLater = model.points(at: 7, state: .idle)
        let reactiveStart = model.points(at: 2, state: .audioReactivePreview)
        let reactiveLater = model.points(at: 7, state: .audioReactivePreview)
        let idleTravel = zip(idleStart, idleLater).reduce(Float.zero) {
            $0 + simd_length($1.0 - $1.1)
        }
        let reactiveTravel = zip(reactiveStart, reactiveLater).reduce(Float.zero) {
            $0 + simd_length($1.0 - $1.1)
        }

        #expect(reactiveTravel > idleTravel * 1.25)
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
            return radius.isFinite
                && radius >= SphereMotion.minimumRadius - 0.0001
                && radius <= SphereMotion.maximumRadius + 0.0001
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
        #expect(energetic.rotationRate == quiet.rotationRate)
        #expect(energetic.rotationRate == SphereMotion.ambientRotationRate)

        let oneAmbientTurn = SphereMotion.orientation(at: 48, state: .idle).y
            - SphereMotion.orientation(at: 0, state: .idle).y
        #expect(abs(oneAmbientTurn - (2 * Float.pi)) < 0.001)
    }

    @Test
    func bassBreathesBroadlyAndLowMidsCreateTravelingWaves() {
        let geometry = IcosphereGeometry.visualizer
        var bassState = VisualizerState.idle
        bassState.bass = 1
        bassState.visualBass = 1
        bassState.energy = 1

        var lowMidState = VisualizerState.idle
        lowMidState.lowMids = 1
        lowMidState.energy = 1
        lowMidState.surfaceDisplacement = 1

        let idleRadii = radii(
            for: geometry,
            state: .idle,
            time: 1,
            response: .zero
        )
        let bassRadii = radii(
            for: geometry,
            state: bassState,
            time: 1,
            response: SphereMotionResponse(bass: 1)
        )
        let lowMidRadii = radii(
            for: geometry,
            state: lowMidState,
            time: 1,
            response: SphereMotionResponse(lowMids: 1)
        )
        let idleMean = idleRadii.reduce(0, +) / Float(idleRadii.count)
        let bassMean = bassRadii.reduce(0, +) / Float(bassRadii.count)

        #expect(bassMean > idleMean + 0.02)
        #expect((lowMidRadii.max()! - lowMidRadii.min()!) > 0.06)
    }

    @Test
    func bassPressureProducesImmediateWooferPushPullAndRebound() {
        let geometry = IcosphereGeometry.visualizer
        let medium = bassPumpingMeans(
            geometry: geometry,
            subBass: 0.35,
            bass: 0.50,
            energy: 0.50
        )
        let strong = bassPumpingMeans(
            geometry: geometry,
            subBass: 0.80,
            bass: 0.90,
            energy: 0.90
        )

        let mediumPeakIndex = medium.indices.max { medium[$0] < medium[$1] }!
        let mediumContractionRange = medium.index(after: mediumPeakIndex)..<medium.endIndex
        let mediumContractionIndex = mediumContractionRange.min {
            medium[$0] < medium[$1]
        }!
        let mediumRebound = medium[medium.index(after: mediumContractionIndex)...].max()!

        #expect(mediumPeakIndex < 20)
        #expect(medium[mediumPeakIndex] > 1.04)
        #expect(medium[mediumContractionIndex] < 0.99)
        #expect(mediumRebound > medium[mediumContractionIndex] + 0.01)
        #expect(strong.max()! > medium.max()! + 0.02)
        #expect(strong.min()! < medium.min()! - 0.008)
        #expect(strong.max()! > 1.075)
        #expect(strong.min()! < 0.97)
    }

    @Test
    func energeticMotionExpandsAndContractsBelowNeutralRadius() {
        let geometry = IcosphereGeometry.visualizer
        var springSystem = SphereSpringSystem()
        var energetic = VisualizerState.audioReactivePreview
        energetic.subBass = 0.9
        energetic.bass = 1
        energetic.visualBass = 1
        energetic.lowMids = 0.9
        energetic.mids = 0.85
        energetic.treble = 0.7
        energetic.energy = 1
        energetic.surfaceDisplacement = 1

        var minimumRadius: Float = 1
        var maximumRadius: Float = 1
        for frame in 0..<240 {
            energetic.beatPulse = frame == 0 ? 1 : 0
            let time = Float(frame) / 60
            let response = springSystem.update(
                state: energetic,
                time: time,
                deltaTime: 1 / 60
            )
            let frameRadii = radii(
                for: geometry,
                state: energetic,
                time: time,
                response: response
            )
            minimumRadius = min(minimumRadius, frameRadii.min()!)
            maximumRadius = max(maximumRadius, frameRadii.max()!)
        }

        #expect(minimumRadius < 0.95)
        #expect(maximumRadius > 1.10)
        #expect(minimumRadius >= SphereMotion.minimumRadius - 0.0001)
        #expect(maximumRadius <= SphereMotion.maximumRadius + 0.0001)
    }

    @Test
    func beatImpulseOvershootsContractsAndRebounds() {
        var springSystem = SphereSpringSystem()
        var state = VisualizerState.idle
        var response: [Float] = []

        for frame in 0..<240 {
            state.beatPulse = frame == 0 ? 1 : 0
            response.append(
                springSystem.update(
                    state: state,
                    time: Float(frame) / 60,
                    deltaTime: 1 / 60
                ).beat
            )
        }

        let peakIndex = response.indices.max { response[$0] < response[$1] }!
        let contractionRange = response.index(after: peakIndex)..<response.endIndex
        let contractionIndex = contractionRange.min { response[$0] < response[$1] }!
        let reboundRange = response.index(after: contractionIndex)..<response.endIndex

        #expect(response[peakIndex] > 0.50)
        #expect(response[contractionIndex] < -0.05)
        #expect(reboundRange.map { response[$0] }.max()! > 0.005)
        #expect(abs(response.last!) < 0.001)
    }

    @Test
    func perceptualCurveLiftsModerateAudioWithoutExceedingBounds() {
        let moderate = SphereMotion.perceptualResponse(0.4)

        #expect(moderate > 0.55)
        #expect(moderate < 1)
        #expect(SphereMotion.perceptualResponse(0) == 0)
        #expect(SphereMotion.perceptualResponse(1) == 1)
    }

    @Test
    func visualBassCompressionHasNoiseFloorAndStrongSignalHeadroom() {
        #expect(VisualBassMapper.response(0) == 0)
        #expect(VisualBassMapper.response(VisualBassMapper.noiseFloor) == 0)
        #expect((0.20...0.30).contains(VisualBassMapper.response(0.05)))
        #expect((0.60...0.70).contains(VisualBassMapper.response(0.20)))
        #expect((0.90...0.97).contains(VisualBassMapper.response(0.70)))
        #expect(VisualBassMapper.response(1) == 1)
        #expect(VisualBassMapper.response(0.7) < VisualBassMapper.response(0.9))
    }

    @Test
    func sustainedBassContinuesPumpingAfterInitialImpulseSettles() {
        var springSystem = SphereSpringSystem()
        var state = VisualizerState.idle
        state.visualBass = 0.78
        var lateResponse: [Float] = []

        for frame in 0..<180 {
            let response = springSystem.update(
                state: state,
                time: Float(frame) / 60,
                deltaTime: 1 / 60
            )
            if frame >= 90 {
                lateResponse.append(response.bass)
            }
        }

        #expect(lateResponse.max()! > 0.15)
        #expect(lateResponse.min()! < -0.15)
    }

    @Test
    func moderateAudioCreatesVisiblePeaksValleysAndTriangleContrastWithinOneSecond() {
        let geometry = IcosphereGeometry.visualizer
        var springSystem = SphereSpringSystem()
        var state = VisualizerState.idle
        state.subBass = 0.42
        state.bass = 0.48
        state.visualBass = VisualBassMapper.response((0.42 * 0.35) + (0.48 * 0.65))
        state.lowMids = 0.45
        state.mids = 0.50
        state.treble = 0.35
        state.energy = 0.50
        state.surfaceDisplacement = 0.50

        var minimumRadius: Float = 1
        var maximumRadius: Float = 1
        var maximumNeighborContrast: Float = 0
        var foundSimultaneousPeakAndValley = false

        for frame in 0..<60 {
            state.beatPulse = frame == 0 ? 0.70 : 0
            let time = Float(frame) / 60
            let response = springSystem.update(
                state: state,
                time: time,
                deltaTime: 1 / 60
            )
            let frameRadii = radii(
                for: geometry,
                state: state,
                time: time,
                response: response
            )
            let frameMinimum = frameRadii.min()!
            let frameMaximum = frameRadii.max()!
            minimumRadius = min(minimumRadius, frameMinimum)
            maximumRadius = max(maximumRadius, frameMaximum)
            maximumNeighborContrast = max(
                maximumNeighborContrast,
                maximumEdgeContrast(radii: frameRadii, geometry: geometry)
            )
            foundSimultaneousPeakAndValley = foundSimultaneousPeakAndValley
                || (frameMinimum < 0.97 && frameMaximum > 1.07)
        }

        #expect(minimumRadius < 0.96)
        #expect(maximumRadius > 1.09)
        #expect(maximumNeighborContrast > 0.045)
        #expect(foundSimultaneousPeakAndValley)
    }

    @Test
    func idleMotionChangesTriangleProportionsOverThreeSeconds() {
        let geometry = IcosphereGeometry.visualizer
        let start = radii(
            for: geometry,
            state: .idle,
            time: 0,
            response: .zero
        )
        let later = radii(
            for: geometry,
            state: .idle,
            time: 3,
            response: .zero
        )
        let averageChange = zip(start, later).reduce(Float.zero) {
            $0 + abs($1.0 - $1.1)
        } / Float(start.count)

        #expect(averageChange > 0.008)
        #expect(maximumEdgeContrast(radii: later, geometry: geometry) > 0.01)
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
        #expect(state.sphereScale == 1)
        #expect(state.surfaceDisplacement > 0)
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
        time: Float,
        response: SphereMotionResponse
    ) -> [Float] {
        geometry.vertices.enumerated().map {
            simd_length(
                SphereMotion.deformedVertex(
                    $0.element,
                    index: $0.offset,
                    time: time,
                    state: state,
                    response: response
                )
            )
        }
    }

    private func maximumEdgeContrast(
        radii: [Float],
        geometry: IcosphereGeometry
    ) -> Float {
        geometry.faces.reduce(Float.zero) { maximum, face in
            let first = Int(face.a)
            let second = Int(face.b)
            let third = Int(face.c)
            let firstEdge = abs(radii[first] - radii[second])
            let secondEdge = abs(radii[second] - radii[third])
            let thirdEdge = abs(radii[third] - radii[first])
            return max(
                maximum,
                max(firstEdge, max(secondEdge, thirdEdge))
            )
        }
    }

    private func bassPumpingMeans(
        geometry: IcosphereGeometry,
        subBass: Float,
        bass: Float,
        energy: Float
    ) -> [Float] {
        var springSystem = SphereSpringSystem()
        var state = VisualizerState.idle
        state.subBass = subBass
        state.bass = bass
        state.visualBass = VisualBassMapper.response(
            (subBass * 0.35) + (bass * 0.65)
        )
        state.energy = energy

        return (0..<60).map { frame in
            let time = Float(frame) / 60
            let response = springSystem.update(
                state: state,
                time: time,
                deltaTime: 1 / 60
            )
            let frameRadii = radii(
                for: geometry,
                state: state,
                time: time,
                response: response
            )
            return frameRadii.reduce(0, +) / Float(frameRadii.count)
        }
    }
}
