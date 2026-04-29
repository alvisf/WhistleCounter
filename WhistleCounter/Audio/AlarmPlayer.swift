import Foundation

/// Plays an alarm (sound + haptic) when the target whistle count is
/// reached. Abstracted behind a protocol so `WhistleSession` doesn't
/// depend on AudioToolbox and can be unit-tested with a mock.
@MainActor
protocol AlarmPlayer: AnyObject {
    /// Begin the alarm with the given sound. Starting again while
    /// already playing replaces the current sound.
    func start(sound: AlarmSound)

    /// Stop the alarm. Safe to call even if the alarm is not playing.
    func stop()
}
