import Foundation
import Observation

/// The top-level observable state for a cooking session.
///
/// Owns the `WhistleDetector`, translates detection callbacks into
/// state that SwiftUI views can render, and exposes control actions
/// (start / stop / reset) to the UI. When a session ends with at
/// least one whistle it is archived to the `HistoryStore`.
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

    /// Name of the recipe selected for the current session, if any.
    /// Set by the Recipes tab; cleared when the session is archived.
    var activeRecipeName: String?

    /// Alarm sound that will play when the target is reached. Set by
    /// `apply(recipe:)`; otherwise falls back to the store's default.
    var activeAlarmSound: AlarmSound

    /// True when there is meaningful session state that the user
    /// would lose if we started a new session on top of it.
    var hasActiveSession: Bool {
        isListening || count > 0
    }

    // MARK: - Collaborators

    private let detector: WhistleDetector
    private let historyStore: HistoryStore?
    private let alarm: AlarmPlayer?
    private let alarmSoundStore: AlarmSoundStore?
    private let clock: () -> Date

    private var sessionStartedAt: Date?

    // MARK: - Init

    init(
        detector: WhistleDetector = DSPWhistleDetector(),
        historyStore: HistoryStore? = nil,
        alarm: AlarmPlayer? = nil,
        alarmSoundStore: AlarmSoundStore? = nil,
        clock: @escaping () -> Date = Date.init
    ) {
        self.detector = detector
        self.historyStore = historyStore
        self.alarm = alarm
        self.alarmSoundStore = alarmSoundStore
        self.activeAlarmSound = alarmSoundStore?.defaultSound ?? .default
        self.clock = clock
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
            if sessionStartedAt == nil {
                sessionStartedAt = clock()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        alarm?.stop()
        if isListening {
            detector.stop()
            isListening = false
        }
        archiveCurrentSessionIfNeeded()
    }

    func reset() {
        stop()
        count = 0
        history.removeAll()
        targetReached = false
        sessionStartedAt = nil
        activeRecipeName = nil
        activeAlarmSound = alarmSoundStore?.defaultSound ?? .default
        alarm?.stop()
    }

    func dismissTargetAlert() {
        targetReached = false
        alarm?.stop()
    }

    /// Apply a recipe to the current session: sets `targetCount`, the
    /// recipe name for history, and the alarm sound override (if any).
    func apply(recipe: Recipe) {
        targetCount = recipe.whistleCount
        activeRecipeName = recipe.name
        activeAlarmSound = recipe.alarmSound
            ?? alarmSoundStore?.defaultSound
            ?? .default
    }

    /// Replace any in-progress session with a fresh one for the given
    /// recipe, then start listening. Used when the user taps a recipe
    /// in the Recipes tab.
    func startFresh(with recipe: Recipe) {
        reset()
        apply(recipe: recipe)
        start()
    }

    // MARK: - Session lifecycle

    /// Persists the current session to history if at least one
    /// whistle has been counted. Called automatically on stop and
    /// reset, so views don't need to call it directly.
    private func archiveCurrentSessionIfNeeded() {
        guard count > 0, let start = sessionStartedAt else { return }
        let record = SessionRecord(
            startedAt: start,
            endedAt: clock(),
            whistleCount: count,
            recipeName: activeRecipeName
        )
        historyStore?.append(record)
        sessionStartedAt = nil
    }

    // MARK: - Callbacks

    private func recordWhistle() {
        count += 1
        history.append(clock())
        if count >= targetCount, !targetReached {
            targetReached = true
            // Stop listening before firing the alarm so the mic's
            // .playAndRecord session releases the audio graph and the
            // alarm's .playback session can take over cleanly.
            stopListeningForAlarm()
            alarm?.start(sound: activeAlarmSound)
        }
    }

    /// Tear down the detector's audio session without archiving or
    /// clearing session state. Archival and state reset happen later
    /// when the user dismisses the alert or hits Stop/Reset.
    private func stopListeningForAlarm() {
        guard isListening else { return }
        detector.stop()
        isListening = false
    }

    private func handleDetectorError(_ message: String) {
        errorMessage = message
        isListening = false
    }

    // MARK: - Boundary clamping

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
