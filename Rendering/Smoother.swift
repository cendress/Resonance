import Foundation

/// A lightweight attack/release exponential smoother for normalized signals.
struct Smoother: Sendable {
    let attack: Float
    let release: Float
    private(set) var value: Float

    init(initialValue: Float = 0, smoothingFactor: Float = 0.15) {
        let factor = Self.clampedFactor(smoothingFactor)
        value = initialValue
        attack = factor
        release = factor
    }

    init(initialValue: Float = 0, attack: Float, release: Float) {
        value = initialValue
        self.attack = Self.clampedFactor(attack)
        self.release = Self.clampedFactor(release)
    }

    @discardableResult
    mutating func update(with target: Float) -> Float {
        let factor = target > value ? attack : release
        value += (target - value) * factor
        return value
    }

    @discardableResult
    mutating func process(_ target: Float) -> Float {
        update(with: target)
    }

    mutating func reset(to newValue: Float = 0) {
        value = newValue
    }

    private static func clampedFactor(_ factor: Float) -> Float {
        min(max(factor.isFinite ? factor : 0, 0), 1)
    }
}
