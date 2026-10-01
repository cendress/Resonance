import SwiftUI

struct VisualizerControlsButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(
            .glass(
                .clear
                    .tint(.white.opacity(0.06))
                    .interactive()
            )
        )
        .buttonBorderShape(.circle)
        .tint(.white.opacity(0.88))
        .overlay {
            Circle()
                .stroke(.white.opacity(0.14), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.16), radius: 5, y: 3)
        .accessibilityLabel("Controls")
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
