import Foundation
import Observation

/// The top-level observable state for a cooking session.
///
/// Owns the `WhistleDetector`, translates detection callbacks into
/// state that SwiftUI views can render, and exposes control actions
/// (start / stop / reset) to the UI.
@Observable
@MainActor
final class WhistleSession {

    // MARK: - Tuning constants

    private enum Defaults {
        static let targetCount: Int = 3
        static let sensitivity: Double = 0.5
    }

    private enum Limits {
        static let minTargetCount: Int = 1
        static let minSensitivity: Double = 0
        static let maxSensitivity: Double = 1
    }

    // MARK: - Public state

    /// Number of whistles detected in the current session.
    private(set) var count: Int = 0

    /// Whether the detector is actively listening.
    private(set) var isListening: Bool = false

    /// User-facing error message, if any (e.g. mic permission denied).
    private(set) var errorMessage: String?

    /// Target whistle count. When `count` reaches this value,
    /// `targetReached` flips to true and the UI shows an alert.
    var targetCount: Int = Defaults.targetCount {
        didSet { clampTargetCount() }
    }

    /// Detection sensitivity in [0, 1].
    /// Higher value = less sensitive (fewer false positives, more misses).
    var sensitivity: Double = Defaults.sensitivity {
        didSet {
            clampSensitivity()
            detector.configure(sensitivity: sensitivity)
        }
    }

    /// True when the target count has just been reached and the user
    /// has not yet dismissed the alert.
    private(set) var targetReached: Bool = false

    /// Timestamps of each detected whistle in the current session.
    private(set) var history: [Date] = []

    // MARK: - Collaborators

    private let detector: WhistleDetector

    // MARK: - Init

    init(detector: WhistleDetector = DSPWhistleDetector()) {
        self.detector = detector
        self.detector.configure(sensitivity: sensitivity)
        self.detector.onWhistleDetected = { [weak self] in
            self?.recordWhistle()
        }
        self.detector.onError = { [weak self] message in
            self?.handleDetectorError(message)
        }
    }

    // MARK: - Actions

    func start() {
        guard !isListening else { return }
        errorMessage = nil
        do {
            try detector.start()
            isListening = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        guard isListening else { return }
        detector.stop()
        isListening = false
    }

    func reset() {
        stop()
        count = 0
        history.removeAll()
        targetReached = false
    }

    func dismissTargetAlert() {
        targetReached = false
    }

    // MARK: - Callbacks

    private func recordWhistle() {
        count += 1
        history.append(Date())
        if count >= targetCount {
            targetReached = true
        }
    }

    private func handleDetectorError(_ message: String) {
        errorMessage = message
        isListening = false
    }

    // MARK: - Boundary clamping
    //
    // Defined as separate methods so the `didSet` observers stay small
    // and easy to read. Each guards against the @Observable macro
    // re-triggering `didSet` by only re-assigning when necessary.

    private func clampTargetCount() {
        if targetCount < Limits.minTargetCount {
            targetCount = Limits.minTargetCount
        }
    }

    private func clampSensitivity() {
        let clamped = min(max(sensitivity, Limits.minSensitivity), Limits.maxSensitivity)
        if sensitivity != clamped {
            sensitivity = clamped
        }
    }
}
