import Observation

@MainActor
@Observable
final class AppState {
    let visualizer: VisualizerViewModel

    init() {
        visualizer = VisualizerViewModel(audioPipeline: AudioPipeline())
    }

    init(audioPipeline: AudioPipeline) {
        visualizer = VisualizerViewModel(audioPipeline: audioPipeline)
    }
}
