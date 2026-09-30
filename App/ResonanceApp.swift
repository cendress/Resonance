import SwiftUI

@main
struct ResonanceApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            VisualizerView(viewModel: appState.visualizer)
                .environment(appState)
        }
    }
}
