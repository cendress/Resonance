import SwiftUI

enum PaletteFamily: String, CaseIterable, Sendable {
    case violet
    case orange
    case blue
    case green
    case red
    case teal
}

struct VisualizerColor: Equatable, Sendable {
    let red: Float
    let green: Float
    let blue: Float

    init(red: Float, green: Float, blue: Float) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    var color: Color {
        Color(red: Double(red), green: Double(green), blue: Double(blue))
    }

    func mixed(with other: VisualizerColor, amount: Float) -> VisualizerColor {
        let amount = Self.clamp(amount)
        return VisualizerColor(
            red: red + ((other.red - red) * amount),
            green: green + ((other.green - green) * amount),
            blue: blue + ((other.blue - blue) * amount)
        )
    }

    func adjusted(saturation: Float = 1, brightness: Float = 1) -> VisualizerColor {
        let luminance = (red * 0.2126) + (green * 0.7152) + (blue * 0.0722)
        return VisualizerColor(
            red: (luminance + ((red - luminance) * saturation)) * brightness,
            green: (luminance + ((green - luminance) * saturation)) * brightness,
            blue: (luminance + ((blue - luminance) * saturation)) * brightness
        )
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}

struct VisualizerPalette: Equatable, Sendable {
    let family: PaletteFamily
    let name: String
    let colors: [VisualizerColor]

    init(family: PaletteFamily, name: String, colors: [VisualizerColor]) {
        precondition(colors.count == 7, "Visualizer palettes require exactly seven colors")
        self.family = family
        self.name = name
        self.colors = colors
    }

    var nearBlack: VisualizerColor { colors[0] }
    var deep: VisualizerColor { colors[1] }
    var shadow: VisualizerColor { colors[2] }
    var rich: VisualizerColor { colors[3] }
    var accent: VisualizerColor { colors[4] }
    var soft: VisualizerColor { colors[5] }
    var light: VisualizerColor { colors[6] }

    // Compatibility roles used throughout the existing view layer.
    var primary: VisualizerColor { deep }
    var secondary: VisualizerColor { rich }

    func interpolated(to target: VisualizerPalette, progress: Float) -> VisualizerPalette {
        let progress = min(max(progress, 0), 1)
        let blendedColors = zip(colors, target.colors).map {
            $0.mixed(with: $1, amount: progress)
        }
        return VisualizerPalette(
            family: progress < 0.5 ? family : target.family,
            name: progress < 0.5 ? name : target.name,
            colors: blendedColors
        )
    }
}

/// Deterministic 4.5-second interpolation used independently by sphere and background.
struct PaletteTransition: Equatable, Sendable {
    private var source: VisualizerPalette
    private var target: VisualizerPalette
    private var startTime: TimeInterval
    let duration: TimeInterval

    init(palette: VisualizerPalette, duration: TimeInterval = 4.5) {
        source = palette
        target = palette
        startTime = 0
        self.duration = duration
    }

    mutating func retarget(to palette: VisualizerPalette, at time: TimeInterval) {
        guard palette != target else { return }
        source = value(at: time)
        target = palette
        startTime = time
    }

    func value(at time: TimeInterval) -> VisualizerPalette {
        guard source != target, duration > 0 else { return target }
        let progress = Float(min(max((time - startTime) / duration, 0), 1))
        let eased = progress * progress * (3 - (2 * progress))
        return source.interpolated(to: target, progress: eased)
    }
}
