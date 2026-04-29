import AudioToolbox
import AVFoundation
import Foundation
import UIKit

/// `AlarmPlayer` that plays a looping system alert sound with a
/// paired haptic, overriding the silent switch.
///
/// Uses `AudioServicesPlayAlertSoundWithCompletion` so the audio
/// session briefly takes over: sound plays through the speaker even
/// if the device is muted, and an automatic vibration is paired on
/// devices that support it.
///
/// Looping is done by restarting the sound from the completion
/// handler. Stopping is best-effort — a sound already in flight will
/// complete, but no new loops are scheduled.
@MainActor
final class SystemAlarmPlayer: AlarmPlayer {

    private enum Alarm {
        /// Apple's "Tri-tone" system sound.
        /// https://github.com/TUNER88/iOSSystemSoundsLibrary
        static let soundID: SystemSoundID = 1005
        static let hapticInterval: TimeInterval = 1.2
    }

    private var isLooping = false
    private let hapticGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)

    func start() {
        guard !isLooping else { return }
        isLooping = true
        configureAudioSessionForAlarm()
        hapticGenerator.notificationOccurred(.warning)
        scheduleNextLoop()
    }

    func stop() {
        guard isLooping else { return }
        isLooping = false
        deactivateAudioSession()
    }

    // MARK: - Private

    private func configureAudioSessionForAlarm() {
        // `.playback` with `mixWithOthers` overrides the silent switch
        // without killing other audio the user might have running.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback,
                                 mode: .default,
                                 options: [.mixWithOthers])
        try? session.setActive(true, options: [])
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func scheduleNextLoop() {
        guard isLooping else { return }

        AudioServicesPlayAlertSoundWithCompletion(Alarm.soundID) { [weak self] in
            Task { @MainActor in
                guard let self, self.isLooping else { return }
                self.impactGenerator.impactOccurred()
                try? await Task.sleep(for: .seconds(Alarm.hapticInterval))
                self.scheduleNextLoop()
            }
        }
    }
}
