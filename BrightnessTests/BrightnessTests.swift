import Testing
@testable import Brightness

struct DDCConversionTests {
    /// With at least 100 raw steps, every percent maps to a distinct raw value.
    @Test(arguments: [100, 255, 65535])
    func percentRoundTripsThroughRawValues(maximum: Int) {
        for percent in 0...100 {
            #expect(DDCDisplay.percent(raw: DDCDisplay.raw(percent: percent, maximum: maximum), maximum: maximum) == percent)
        }
    }

    /// With coarser monitors, every raw value is still reachable from a percent.
    @Test(arguments: [10, 50, 100])
    func everyRawValueIsReachable(maximum: Int) {
        for raw in 0...maximum {
            #expect(DDCDisplay.raw(percent: DDCDisplay.percent(raw: raw, maximum: maximum), maximum: maximum) == raw)
        }
    }

    @Test func handlesEdgeCases() {
        #expect(DDCDisplay.percent(raw: 5, maximum: 50) == 10) // Odyssey G5 reports a maximum of 50
        #expect(DDCDisplay.percent(raw: 0, maximum: 0) == 0)
        #expect(DDCDisplay.raw(percent: 150, maximum: 100) == 100)
        #expect(DDCDisplay.raw(percent: -5, maximum: 100) == 0)
    }
}

struct TransitionTests {
    @Test func stepsTowardsTargetWithoutOvershooting() {
        #expect(BrightnessService.step(from: 10, towards: 30, maxStep: 4) == 14)
        #expect(BrightnessService.step(from: 28, towards: 30, maxStep: 4) == 30)
        #expect(BrightnessService.step(from: 30, towards: 10, maxStep: 4) == 26)
        #expect(BrightnessService.step(from: 2, towards: 0, maxStep: 4) == 0)
        #expect(BrightnessService.step(from: 10, towards: 90, maxStep: 100) == 90)
    }
}
