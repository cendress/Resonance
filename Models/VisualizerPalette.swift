import SwiftUI

struct VisualizerColor: Equatable, Sendable {
    let red: Float
    let green: Float
    let blue: Float

    var color: Color {
        Color(red: Double(red), green: Double(green), blue: Double(blue))
    }
}

struct VisualizerPalette: Equatable, Sendable {
    let name: String
    let primary: VisualizerColor
    let secondary: VisualizerColor
    let accent: VisualizerColor
}
