import Testing
@testable import Resonance

struct SmootherTests {
    @Test
    func usesAttackWhenSignalRises() {
        var smoother = Smoother(initialValue: 0, attack: 0.5, release: 0.1)

        let value = smoother.process(1)

        #expect(value == 0.5)
    }

    @Test
    func usesSlowerReleaseWhenSignalFalls() {
        var smoother = Smoother(initialValue: 1, attack: 0.5, release: 0.1)

        let value = smoother.process(0)

        #expect(value == 0.9)
    }

    @Test
    func attackRespondsFasterThanRelease() {
        var rising = Smoother(initialValue: 0, attack: 0.7, release: 0.08)
        var falling = Smoother(initialValue: 1, attack: 0.7, release: 0.08)

        let rise = rising.process(1)
        let fall = 1 - falling.process(0)

        #expect(rise > fall)
    }

    @Test
    func resetReplacesCurrentValue() {
        var smoother = Smoother(initialValue: 0.25)
        _ = smoother.process(1)

        smoother.reset(to: 0.4)

        #expect(smoother.value == 0.4)
    }

    @Test
    func invalidFactorsAreClamped() {
        var smoother = Smoother(initialValue: 0, attack: 2, release: -1)

        #expect(smoother.process(1) == 1)
        #expect(smoother.process(0) == 1)
    }
}
