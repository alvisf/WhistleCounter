import XCTest
@testable import WhistleCounter

/// A stand-in `WhistleDetector` used to drive `WhistleSession`
/// without touching real audio hardware.
@MainActor
final class MockWhistleDetector: WhistleDetector {
    var onWhistleDetected: (() -> Void)?
    var onError: ((String) -> Void)?

    private(set) var startCalls = 0
    private(set) var stopCalls = 0
    private(set) var lastSensitivity: Double?
    var shouldThrowOnStart: Error?

    func start() throws {
        startCalls += 1
        if let error = shouldThrowOnStart { throw error }
    }

    func stop() { stopCalls += 1 }

    func configure(sensitivity: Double) {
        lastSensitivity = sensitivity
    }

    /// Test helper — simulate a real detection event.
    func fireWhistle() { onWhistleDetected?() }

    /// Test helper — simulate a detection error.
    func fireError(_ message: String) { onError?(message) }
}

@MainActor
final class WhistleSessionTests: XCTestCase {

    func testInitialState() {
        let session = WhistleSession(detector: MockWhistleDetector())
        XCTAssertEqual(session.count, 0)
        XCTAssertFalse(session.isListening)
        XCTAssertEqual(session.targetCount, 3)
        XCTAssertFalse(session.targetReached)
        XCTAssertNil(session.errorMessage)
    }

    func testStart_setsIsListening() {
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock)
        session.start()
        XCTAssertTrue(session.isListening)
        XCTAssertEqual(mock.startCalls, 1)
    }

    func testStart_propagatesErrorAndStaysStopped() {
        let mock = MockWhistleDetector()
        mock.shouldThrowOnStart = NSError(
            domain: "Test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "nope"]
        )
        let session = WhistleSession(detector: mock)
        session.start()
        XCTAssertFalse(session.isListening)
        XCTAssertEqual(session.errorMessage, "nope")
    }

    func testStop_isIdempotent() {
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock)
        session.start()
        session.stop()
        session.stop()
        XCTAssertFalse(session.isListening)
        XCTAssertEqual(mock.stopCalls, 1)
    }

    func testDetection_incrementsCountAndHistory() {
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock)
        session.start()
        mock.fireWhistle()
        mock.fireWhistle()
        XCTAssertEqual(session.count, 2)
        XCTAssertEqual(session.history.count, 2)
    }

    func testDetection_hittingTarget_setsTargetReached() {
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock)
        session.targetCount = 2
        session.start()
        mock.fireWhistle()
        XCTAssertFalse(session.targetReached)
        mock.fireWhistle()
        XCTAssertTrue(session.targetReached)
    }

    func testReset_clearsEverything() {
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock)
        session.start()
        mock.fireWhistle()
        mock.fireWhistle()
        session.reset()
        XCTAssertEqual(session.count, 0)
        XCTAssertTrue(session.history.isEmpty)
        XCTAssertFalse(session.isListening)
        XCTAssertFalse(session.targetReached)
    }

    func testSensitivity_isClampedAndForwarded() {
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock)
        session.sensitivity = 1.5
        XCTAssertEqual(session.sensitivity, 1.0)
        XCTAssertEqual(mock.lastSensitivity, 1.0)

        session.sensitivity = -0.5
        XCTAssertEqual(session.sensitivity, 0.0)
        XCTAssertEqual(mock.lastSensitivity, 0.0)
    }

    func testDetectorError_stopsSessionAndShowsMessage() {
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock)
        session.start()
        mock.fireError("mic denied")
        XCTAssertFalse(session.isListening)
        XCTAssertEqual(session.errorMessage, "mic denied")
    }

    func testTargetCount_isClampedAboveZero() {
        let session = WhistleSession(detector: MockWhistleDetector())
        session.targetCount = 0
        XCTAssertEqual(session.targetCount, 1)
        session.targetCount = -5
        XCTAssertEqual(session.targetCount, 1)
    }
}
