import XCTest
@testable import WhistleCounter

/// A stand-in `WhistleDetector` that records interactions from tests
/// and exposes helpers to simulate detection events.
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

    func fireWhistle() { onWhistleDetected?() }
    func fireError(_ message: String) { onError?(message) }
}

@MainActor
final class MockAlarmPlayer: AlarmPlayer {
    private(set) var startCalls = 0
    private(set) var stopCalls = 0

    func start() { startCalls += 1 }
    func stop() { stopCalls += 1 }
}

@MainActor
final class WhistleSessionTests: XCTestCase {

    private func makeSession(
        mock: MockWhistleDetector = MockWhistleDetector()
    ) -> (WhistleSession, MockWhistleDetector) {
        (WhistleSession(detector: mock), mock)
    }

    // MARK: - Initial state

    func testInitialCount_isZero() {
        let (session, _) = makeSession()
        XCTAssertEqual(session.count, 0)
    }

    func testInitially_isNotListening() {
        let (session, _) = makeSession()
        XCTAssertFalse(session.isListening)
    }

    func testInitialTargetCount_isThree() {
        let (session, _) = makeSession()
        XCTAssertEqual(session.targetCount, 3)
    }

    func testInitially_targetNotReached() {
        let (session, _) = makeSession()
        XCTAssertFalse(session.targetReached)
    }

    func testInitially_hasNoErrorMessage() {
        let (session, _) = makeSession()
        XCTAssertNil(session.errorMessage)
    }

    // MARK: - Start / stop

    func testStart_setsIsListening() {
        let (session, _) = makeSession()
        session.start()
        XCTAssertTrue(session.isListening)
    }

    func testStart_callsDetectorStart() {
        let (session, mock) = makeSession()
        session.start()
        XCTAssertEqual(mock.startCalls, 1)
    }

    func testStart_whenDetectorThrows_staysStopped() {
        let (session, mock) = makeSession()
        mock.shouldThrowOnStart = NSError(
            domain: "Test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "nope"]
        )
        session.start()
        XCTAssertFalse(session.isListening)
    }

    func testStart_whenDetectorThrows_propagatesErrorMessage() {
        let (session, mock) = makeSession()
        mock.shouldThrowOnStart = NSError(
            domain: "Test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "nope"]
        )
        session.start()
        XCTAssertEqual(session.errorMessage, "nope")
    }

    func testStop_isIdempotent_detectorStoppedOnlyOnce() {
        let (session, mock) = makeSession()
        session.start()
        session.stop()
        session.stop()
        XCTAssertEqual(mock.stopCalls, 1)
    }

    // MARK: - Detection

    func testDetection_incrementsCount() {
        let (session, mock) = makeSession()
        session.start()
        mock.fireWhistle()
        mock.fireWhistle()
        XCTAssertEqual(session.count, 2)
    }

    func testDetection_appendsToHistory() {
        let (session, mock) = makeSession()
        session.start()
        mock.fireWhistle()
        mock.fireWhistle()
        XCTAssertEqual(session.history.count, 2)
    }

    func testDetection_belowTarget_targetNotReached() {
        let (session, mock) = makeSession()
        session.targetCount = 2
        session.start()
        mock.fireWhistle()
        XCTAssertFalse(session.targetReached)
    }

    func testDetection_hittingTarget_setsTargetReached() {
        let (session, mock) = makeSession()
        session.targetCount = 2
        session.start()
        mock.fireWhistle()
        mock.fireWhistle()
        XCTAssertTrue(session.targetReached)
    }

    // MARK: - Reset

    func testReset_clearsCount() {
        let (session, mock) = makeSession()
        session.start()
        mock.fireWhistle()
        mock.fireWhistle()
        session.reset()
        XCTAssertEqual(session.count, 0)
    }

    func testReset_clearsHistory() {
        let (session, mock) = makeSession()
        session.start()
        mock.fireWhistle()
        session.reset()
        XCTAssertTrue(session.history.isEmpty)
    }

    func testReset_stopsListening() {
        let (session, _) = makeSession()
        session.start()
        session.reset()
        XCTAssertFalse(session.isListening)
    }

    func testReset_clearsTargetReached() {
        let (session, mock) = makeSession()
        session.targetCount = 1
        session.start()
        mock.fireWhistle()
        session.reset()
        XCTAssertFalse(session.targetReached)
    }

    // MARK: - Sensitivity clamping

    func testSensitivity_aboveMax_isClampedToOne() {
        let (session, _) = makeSession()
        session.sensitivity = 1.5
        XCTAssertEqual(session.sensitivity, 1.0)
    }

    func testSensitivity_aboveMax_isForwardedClampedToDetector() {
        let (session, mock) = makeSession()
        session.sensitivity = 1.5
        XCTAssertEqual(mock.lastSensitivity, 1.0)
    }

    func testSensitivity_belowMin_isClampedToZero() {
        let (session, _) = makeSession()
        session.sensitivity = -0.5
        XCTAssertEqual(session.sensitivity, 0.0)
    }

    func testSensitivity_belowMin_isForwardedClampedToDetector() {
        let (session, mock) = makeSession()
        session.sensitivity = -0.5
        XCTAssertEqual(mock.lastSensitivity, 0.0)
    }

    // MARK: - Target-count clamping

    func testTargetCount_zero_isClampedToOne() {
        let (session, _) = makeSession()
        session.targetCount = 0
        XCTAssertEqual(session.targetCount, 1)
    }

    func testTargetCount_negative_isClampedToOne() {
        let (session, _) = makeSession()
        session.targetCount = -5
        XCTAssertEqual(session.targetCount, 1)
    }

    // MARK: - Detector error handling

    func testDetectorError_stopsSession() {
        let (session, mock) = makeSession()
        session.start()
        mock.fireError("mic denied")
        XCTAssertFalse(session.isListening)
    }

    func testDetectorError_setsErrorMessage() {
        let (session, mock) = makeSession()
        session.start()
        mock.fireError("mic denied")
        XCTAssertEqual(session.errorMessage, "mic denied")
    }

    // MARK: - Session archival to HistoryStore

    private func makeHistoryStore() -> HistoryStore {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("history-\(UUID().uuidString).json")
        return HistoryStore(fileURL: tempFile)
    }

    func testStop_withZeroCount_doesNotArchive() {
        let history = makeHistoryStore()
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock, historyStore: history)
        session.start()
        session.stop()
        XCTAssertTrue(history.records.isEmpty)
    }

    func testStop_withPositiveCount_archivesSession() {
        let history = makeHistoryStore()
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock, historyStore: history)
        session.start()
        mock.fireWhistle()
        session.stop()
        XCTAssertEqual(history.records.count, 1)
    }

    func testArchivedRecord_hasCorrectWhistleCount() {
        let history = makeHistoryStore()
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock, historyStore: history)
        session.start()
        mock.fireWhistle()
        mock.fireWhistle()
        session.stop()
        XCTAssertEqual(history.records.first?.whistleCount, 2)
    }

    func testArchivedRecord_includesActiveRecipeName() {
        let history = makeHistoryStore()
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock, historyStore: history)
        session.apply(recipe: Recipe(name: "Rajma", whistleCount: 6))
        session.start()
        mock.fireWhistle()
        session.stop()
        XCTAssertEqual(history.records.first?.recipeName, "Rajma")
    }

    func testReset_archivesBeforeClearing() {
        let history = makeHistoryStore()
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock, historyStore: history)
        session.start()
        mock.fireWhistle()
        session.reset()
        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(session.count, 0)
    }

    func testReset_withZeroCount_doesNotArchive() {
        let history = makeHistoryStore()
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock, historyStore: history)
        session.start()
        session.reset()
        XCTAssertTrue(history.records.isEmpty)
    }

    // MARK: - Recipe application

    func testApplyRecipe_setsTargetCount() {
        let (session, _) = makeSession()
        session.apply(recipe: Recipe(name: "Rajma", whistleCount: 6))
        XCTAssertEqual(session.targetCount, 6)
    }

    func testApplyRecipe_setsActiveRecipeName() {
        let (session, _) = makeSession()
        session.apply(recipe: Recipe(name: "Rajma", whistleCount: 6))
        XCTAssertEqual(session.activeRecipeName, "Rajma")
    }

    // MARK: - Alarm

    func testAlarm_startsWhenTargetReached() {
        let alarm = MockAlarmPlayer()
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock, alarm: alarm)
        session.targetCount = 2
        session.start()
        mock.fireWhistle()
        XCTAssertEqual(alarm.startCalls, 0)
        mock.fireWhistle()
        XCTAssertEqual(alarm.startCalls, 1)
    }

    func testAlarm_doesNotRestartOnSubsequentWhistles() {
        let alarm = MockAlarmPlayer()
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock, alarm: alarm)
        session.targetCount = 1
        session.start()
        mock.fireWhistle()
        mock.fireWhistle()
        mock.fireWhistle()
        XCTAssertEqual(alarm.startCalls, 1)
    }

    func testAlarm_stopsWhenUserDismissesAlert() {
        let alarm = MockAlarmPlayer()
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock, alarm: alarm)
        session.targetCount = 1
        session.start()
        mock.fireWhistle()
        session.dismissTargetAlert()
        XCTAssertEqual(alarm.stopCalls, 1)
    }

    func testAlarm_stopsOnSessionStop() {
        let alarm = MockAlarmPlayer()
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock, alarm: alarm)
        session.targetCount = 1
        session.start()
        mock.fireWhistle()
        session.stop()
        XCTAssertGreaterThanOrEqual(alarm.stopCalls, 1)
    }

    func testAlarm_stopsOnReset() {
        let alarm = MockAlarmPlayer()
        let mock = MockWhistleDetector()
        let session = WhistleSession(detector: mock, alarm: alarm)
        session.targetCount = 1
        session.start()
        mock.fireWhistle()
        session.reset()
        XCTAssertGreaterThanOrEqual(alarm.stopCalls, 1)
    }
}
