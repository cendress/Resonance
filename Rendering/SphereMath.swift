import Foundation

enum SphereMath {
    static func clamp(_ value: Float, lowerBound: Float = 0, upperBound: Float = 1) -> Float {
        min(max(value, lowerBound), upperBound)
    }
}
