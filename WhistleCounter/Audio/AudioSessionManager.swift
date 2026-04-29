import AVFoundation
import Foundation

/// Manages the shared `AVAudioSession` configuration used by the
/// detector. Isolated so it can be mocked/bypassed in unit tests.
enum AudioSessionManager {

    /// Configure the session for microphone recording with measurement
    /// mode (disables AGC and echo cancellation, giving us a cleaner
    /// signal for DSP analysis).
    static func configure() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true, options: [.notifyOthersOnDeactivation])
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Request microphone permission. Async wrapper around the
    /// platform-appropriate permission API (iOS 17+ uses
    /// `AVAudioApplication.requestRecordPermission`).
    static func requestMicPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
