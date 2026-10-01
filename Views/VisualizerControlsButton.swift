import SwiftUI

struct VisualizerControlsButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label("Controls", systemImage: "slider.horizontal.3")
                .font(.headline)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("Opens visualizer controls")
    }
}

#Preview("Controls Button") {
    @Previewable @State var isPresented = false

    ZStack {
        Color.black
        VisualizerControlsButton(isPresented: $isPresented)
    }
    .preferredColorScheme(.dark)
}
