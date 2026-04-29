import Foundation

/// Abstract interface for whistle detection.
///
/// Concrete implementations:
/// - `DSPWhistleDetector` — FFT band-energy threshold (default, deterministic).
/// - A future `SoundAnalysisWhistleDetector` — Core ML `SoundAnalysis`
///   classifier, swap in without changing the callsite.
@MainActor
protocol WhistleDetector: AnyObject {

    /// Called on the main actor each time a whistle is detected.
    var onWhistleDetected: (() -> Void)? { get set }

    /// Called on the main actor on fatal detection errors
    /// (permission denied, engine failed to start, etc.).
    var onError: ((String) -> Void)? { get set }

    /// Start listening. Throws if the audio engine can't be started.
    func start() throws

    /// Stop listening. Idempotent.
    func stop()

    /// Update sensitivity in [0, 1]. Higher = less sensitive.
    func configure(sensitivity: Double)
}
