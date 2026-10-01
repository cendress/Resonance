import Foundation

enum PaletteLibrary {
    static let violet = VisualizerPalette(
        family: .violet,
        name: "Violet",
        colors: [
            rgb(0.025, 0.018, 0.075), // near-black indigo
            rgb(0.035, 0.060, 0.145), // deep navy
            rgb(0.145, 0.050, 0.180), // eggplant
            rgb(0.310, 0.105, 0.470), // rich violet
            rgb(0.520, 0.190, 0.520), // muted magenta
            rgb(0.570, 0.480, 0.700), // dusty lavender
            rgb(0.805, 0.745, 0.900)  // pale lilac
        ]
    )

    static let orange = VisualizerPalette(
        family: .orange,
        name: "Orange",
        colors: [
            rgb(0.055, 0.020, 0.012),
            rgb(0.120, 0.038, 0.020),
            rgb(0.245, 0.065, 0.025),
            rgb(0.520, 0.150, 0.035),
            rgb(0.820, 0.315, 0.075),
            rgb(0.875, 0.535, 0.235),
            rgb(0.955, 0.755, 0.485)
        ]
    )

    static let blue = VisualizerPalette(
        family: .blue,
        name: "Blue",
        colors: [
            rgb(0.008, 0.025, 0.060),
            rgb(0.015, 0.060, 0.135),
            rgb(0.025, 0.120, 0.245),
            rgb(0.040, 0.255, 0.500),
            rgb(0.135, 0.435, 0.720),
            rgb(0.365, 0.610, 0.800),
            rgb(0.680, 0.815, 0.920)
        ]
    )

    static let green = VisualizerPalette(
        family: .green,
        name: "Green",
        colors: [
            rgb(0.008, 0.045, 0.030),
            rgb(0.020, 0.105, 0.060),
            rgb(0.035, 0.195, 0.105),
            rgb(0.075, 0.360, 0.165),
            rgb(0.190, 0.555, 0.275),
            rgb(0.445, 0.695, 0.465),
            rgb(0.720, 0.855, 0.690)
        ]
    )

    static let red = VisualizerPalette(
        family: .red,
        name: "Red",
        colors: [
            rgb(0.055, 0.008, 0.020),
            rgb(0.130, 0.018, 0.038),
            rgb(0.255, 0.030, 0.060),
            rgb(0.510, 0.055, 0.095),
            rgb(0.745, 0.125, 0.150),
            rgb(0.790, 0.365, 0.375),
            rgb(0.925, 0.660, 0.640)
        ]
    )

    static let teal = VisualizerPalette(
        family: .teal,
        name: "Teal",
        colors: [
            rgb(0.005, 0.040, 0.045),
            rgb(0.010, 0.095, 0.105),
            rgb(0.020, 0.185, 0.195),
            rgb(0.035, 0.345, 0.345),
            rgb(0.100, 0.535, 0.500),
            rgb(0.365, 0.690, 0.630),
            rgb(0.670, 0.855, 0.790)
        ]
    )

    static let all: [VisualizerPalette] = [
        violet,
        orange,
        blue,
        green,
        red,
        teal
    ]

    // Compatibility aliases from the prototype.
    static let midnight = violet
    static let ember = orange
    static let aurora = teal

    static func palette(for family: PaletteFamily) -> VisualizerPalette {
        switch family {
        case .violet: violet
        case .orange: orange
        case .blue: blue
        case .green: green
        case .red: red
        case .teal: teal
        }
    }

    private static func rgb(_ red: Float, _ green: Float, _ blue: Float) -> VisualizerColor {
        VisualizerColor(red: red, green: green, blue: blue)
    }
}
