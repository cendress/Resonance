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
    func usesReleaseWhenSignalFalls() {
        var smoother = Smoother(initialValue: 1, attack: 0.5, release: 0.25)

        let value = smoother.process(0)

        #expect(value == 0.75)
    }

    @Test
    func resetReplacesCurrentValue() {
        var smoother = Smoother(initialValue: 0.25)
        _ = smoother.process(1)

        smoother.reset(to: 0.4)

        #expect(smoother.value == 0.4)
    }
}
