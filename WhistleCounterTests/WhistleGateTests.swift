import XCTest
@testable import WhistleCounter

final class WhistleGateTests: XCTestCase {

    // MARK: - helpers

    /// Drive `gate.process` for `seconds` at 100 Hz feeding the given
    /// energy ratio. Returns the number of times the gate fired.
    private func run(
        gate: inout WhistleGate,
        ratio: Float,
        seconds: Double,
        startingAt start: TimeInterval = 0
    ) -> Int {
        let step = 0.01
        var fires = 0
        var t = start
        let end = start + seconds
        while t <= end {
            if gate.process(energyRatio: ratio, now: t) {
                fires += 1
            }
            t += step
        }
        return fires
    }

    // MARK: - tests

    func testBelowThreshold_doesNotFire() {
        var gate = WhistleGate(
            thresholdRatio: 0.3,
            minDurationSec: 0.3,
            refractorySec: 1.5
        )
        let fires = run(gate: &gate, ratio: 0.1, seconds: 5)
        XCTAssertEqual(fires, 0)
    }

    func testAboveThreshold_butShorterThanMinDuration_doesNotFire() {
        var gate = WhistleGate(
            thresholdRatio: 0.3,
            minDurationSec: 0.3,
            refractorySec: 1.5
        )
        // 0.2 s of high energy — below the 0.3 s minimum.
        let fires = run(gate: &gate, ratio: 0.5, seconds: 0.2)
        XCTAssertEqual(fires, 0)
    }

    func testAboveThreshold_pastMinDuration_firesOnce() {
        var gate = WhistleGate(
            thresholdRatio: 0.3,
            minDurationSec: 0.3,
            refractorySec: 1.5
        )
        // Sustained high energy — should fire exactly once within the
        // refractory window.
        let fires = run(gate: &gate, ratio: 0.5, seconds: 1.0)
        XCTAssertEqual(fires, 1)
    }

    func testTwoWhistles_separatedByRefractory_fireTwice() {
        var gate = WhistleGate(
            thresholdRatio: 0.3,
            minDurationSec: 0.3,
            refractorySec: 1.0
        )
        var fires = 0
        // First whistle: 0.4 s of signal starting at t=0.
        fires += run(gate: &gate, ratio: 0.5, seconds: 0.4, startingAt: 0)
        // Silence for > refractory.
        fires += run(gate: &gate, ratio: 0.0, seconds: 1.2, startingAt: 0.4)
        // Second whistle: another 0.4 s of signal.
        fires += run(gate: &gate, ratio: 0.5, seconds: 0.4, startingAt: 1.6)
        XCTAssertEqual(fires, 2)
    }

    func testTwoWhistles_withinRefractory_fireOnlyOnce() {
        var gate = WhistleGate(
            thresholdRatio: 0.3,
            minDurationSec: 0.3,
            refractorySec: 2.0
        )
        var fires = 0
        fires += run(gate: &gate, ratio: 0.5, seconds: 0.4, startingAt: 0)
        // Drop for a short time (shorter than refractorySec).
        fires += run(gate: &gate, ratio: 0.0, seconds: 0.5, startingAt: 0.4)
        fires += run(gate: &gate, ratio: 0.5, seconds: 0.4, startingAt: 0.9)
        // Second burst too soon — refractory suppresses it.
        XCTAssertEqual(fires, 1)
    }
}
