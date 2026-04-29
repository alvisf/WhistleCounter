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

    // MARK: - Public state

    /// Whistles detected in the current session.
    private(set) var count: Int = 0

    /// Whether the detector is actively listening.
    private(set) var isListening: Bool = false

    /// User-facing error message, if any (e.g. mic permission denied).
    private(set) var errorMessage: String?

    /// Target whistle count. When `count` reaches this, `targetReached`
    /// flips true and the UI shows an alert.
    var targetCount: Int = 3 {
        didSet {
            if targetCount < 1 { targetCount = 1 }
        }
    }

    /// Detection threshold as a normalized energy ratio in [0, 1].
    /// Higher = less sensitive (fewer false positives, more misses).
    var sensitivity: Double = 0.5 {
        didSet {
            let clamped = min(max(sensitivity, 0), 1)
            if sensitivity != clamped {
                sensitivity = clamped
            }
            detector.configure(sensitivity: sensitivity)
        }
    }

    /// True when `count >= targetCount` and the user hasn't dismissed
    /// the alert yet.
    private(set) var targetReached: Bool = false

    /// Timestamps of each detected whistle for this session.
    private(set) var history: [Date] = []

    // MARK: - Init

    private let detector: WhistleDetector

    init(detector: WhistleDetector = DSPWhistleDetector()) {
        self.detector = detector
        self.detector.configure(sensitivity: sensitivity)
        self.detector.onWhistleDetected = { [weak self] in
            self?.handleWhistle()
        }
        self.detector.onError = { [weak self] message in
            self?.errorMessage = message
            self?.isListening = false
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

    // MARK: - Private

    private func handleWhistle() {
        count += 1
        history.append(Date())
        if count >= targetCount {
            targetReached = true
        }
    }
}
