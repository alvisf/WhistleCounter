import XCTest
@testable import WhistleCounter

final class WhistleGateTests: XCTestCase {

    // MARK: - Helpers

    /// The simulated inter-frame interval used when driving the gate.
    /// Matches a 100 Hz polling rate, which is close to real audio
    /// tap rates and gives us fine-grained timing in tests.
    private static let samplingIntervalSec: Double = 0.01

    /// Drive `gate.process` for `seconds` at 100 Hz feeding the given
    /// energy ratio. Returns the total number of times the gate fired.
    private func run(
        gate: inout WhistleGate,
        ratio: Float,
        seconds: Double,
        startingAt start: TimeInterval = 0
    ) -> Int {
        var fireCount = 0
        var time = start
        let end = start + seconds
        while time <= end {
            if gate.process(energyRatio: ratio, now: time) {
                fireCount += 1
            }
            time += Self.samplingIntervalSec
        }
        return fireCount
    }

    private func makeGate(
        fireRatio: Float = 0.3,
        minDurationSec: Double = 0.3,
        refractorySec: Double = 1.5,
        minGapSec: Double = 0.5
    ) -> WhistleGate {
        WhistleGate(
            thresholdRatio: fireRatio,
            minDurationSec: minDurationSec,
            refractorySec: refractorySec,
            minGapSec: minGapSec
        )
    }

    // MARK: - Threshold and duration

    func testBelowThreshold_doesNotFire() {
        var gate = makeGate()
        let fires = run(gate: &gate, ratio: 0.1, seconds: 5)
        XCTAssertEqual(fires, 0)
    }

    func testAboveThreshold_butShorterThanMinDuration_doesNotFire() {
        var gate = makeGate()
        // 0.2 s of high energy — below the 0.3 s minimum.
        let fires = run(gate: &gate, ratio: 0.5, seconds: 0.2)
        XCTAssertEqual(fires, 0)
    }

    func testAboveThreshold_pastMinDuration_firesOnce() {
        var gate = makeGate()
        let fires = run(gate: &gate, ratio: 0.5, seconds: 1.0)
        XCTAssertEqual(fires, 1)
    }

    // MARK: - Refractory period

    func testTwoWhistles_separatedByRefractory_fireTwice() {
        var gate = makeGate(refractorySec: 1.0)
        var fires = 0
        fires += run(gate: &gate, ratio: 0.5, seconds: 0.4, startingAt: 0.0)
        fires += run(gate: &gate, ratio: 0.0, seconds: 1.2, startingAt: 0.4)
        fires += run(gate: &gate, ratio: 0.5, seconds: 0.4, startingAt: 1.6)
        XCTAssertEqual(fires, 2)
    }

    func testTwoWhistles_withinRefractory_fireOnlyOnce() {
        var gate = makeGate(refractorySec: 2.0)
        var fires = 0
        fires += run(gate: &gate, ratio: 0.5, seconds: 0.4, startingAt: 0.0)
        fires += run(gate: &gate, ratio: 0.0, seconds: 0.5, startingAt: 0.4)
        fires += run(gate: &gate, ratio: 0.5, seconds: 0.4, startingAt: 0.9)
        XCTAssertEqual(fires, 1)
    }

    // MARK: - Long whistles

    func testLongSingleWhistle_10s_firesOnce() {
        var gate = makeGate()
        let fires = run(gate: &gate, ratio: 0.5, seconds: 10.0)
        XCTAssertEqual(fires, 1)
    }

    func testLongSingleWhistle_5s_firesOnce() {
        var gate = makeGate()
        let fires = run(gate: &gate, ratio: 0.5, seconds: 5.0)
        XCTAssertEqual(fires, 1)
    }

    func testLongWhistle_thenSilence_thenNewWhistle_firesTwice() {
        var gate = makeGate(refractorySec: 1.0)
        var fires = 0
        fires += run(gate: &gate, ratio: 0.5, seconds: 4.0, startingAt: 0.0)
        fires += run(gate: &gate, ratio: 0.0, seconds: 1.2, startingAt: 4.0)
        fires += run(gate: &gate, ratio: 0.5, seconds: 1.0, startingAt: 5.2)
        XCTAssertEqual(fires, 2)
    }

    // MARK: - Mid-whistle wobbles (regression)

    func testBriefDropoutMidWhistle_doesNotDoubleCount() {
        var gate = makeGate()
        var fires = 0
        fires += run(gate: &gate, ratio: 0.5, seconds: 1.0, startingAt: 0.0)
        fires += run(gate: &gate, ratio: 0.0, seconds: 0.05, startingAt: 1.0)
        fires += run(gate: &gate, ratio: 0.5, seconds: 1.0, startingAt: 1.05)
        XCTAssertEqual(fires, 1)
    }

    /// Regression: a second whistle whose amplitude dipped between
    /// fireRatio and releaseRatio was being counted twice.
    func testSecondWhistle_withDipAboveReleaseRatio_countsAsOne() {
        var gate = makeGate()
        var fires = 0
        fires += run(gate: &gate, ratio: 0.5, seconds: 3.0, startingAt: 0.0)
        fires += run(gate: &gate, ratio: 0.0, seconds: 1.0, startingAt: 3.0)
        // Whistle 2 with an internal dip to 0.15:
        //   - below fireRatio (0.3)
        //   - above releaseRatio (0.18)
        // Hysteresis must keep this as a single whistle.
        fires += run(gate: &gate, ratio: 0.5,  seconds: 2.0, startingAt: 4.0)
        fires += run(gate: &gate, ratio: 0.15, seconds: 0.3, startingAt: 6.0)
        fires += run(gate: &gate, ratio: 0.5,  seconds: 2.0, startingAt: 6.3)
        XCTAssertEqual(fires, 2)
    }

    /// Regression: a short dropout below the release ratio — shorter
    /// than `minGapSec` — must not re-arm the gate.
    func testSecondWhistle_withDipBelowRelease_shorterThanMinGap_countsAsOne() {
        var gate = makeGate()
        var fires = 0
        fires += run(gate: &gate, ratio: 0.5, seconds: 1.0, startingAt: 0.0)
        fires += run(gate: &gate, ratio: 0.0, seconds: 0.8, startingAt: 1.0)
        fires += run(gate: &gate, ratio: 0.5, seconds: 2.0, startingAt: 1.8)
        fires += run(gate: &gate, ratio: 0.0, seconds: 0.2, startingAt: 3.8)
        fires += run(gate: &gate, ratio: 0.5, seconds: 2.0, startingAt: 4.0)
        XCTAssertEqual(fires, 2)
    }

    func testThreeRealisticWhistles_eachWithWobble_countsAsThree() {
        var gate = makeGate()
        var fires = 0
        var cursor: Double = 0

        for _ in 0..<3 {
            fires += run(gate: &gate, ratio: 0.5,  seconds: 1.2, startingAt: cursor)
            fires += run(gate: &gate, ratio: 0.22, seconds: 0.2, startingAt: cursor + 1.2)
            fires += run(gate: &gate, ratio: 0.5,  seconds: 1.6, startingAt: cursor + 1.4)
            cursor += 3.0
            fires += run(gate: &gate, ratio: 0.0, seconds: 1.0, startingAt: cursor)
            cursor += 1.0
        }
        XCTAssertEqual(fires, 3)
    }
}
