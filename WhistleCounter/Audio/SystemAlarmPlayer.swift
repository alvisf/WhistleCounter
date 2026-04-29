import AudioToolbox
import AVFoundation
import Foundation
import UIKit

/// `AlarmPlayer` that plays a looping iOS system alert sound with a
/// paired haptic, overriding the silent switch.
@MainActor
final class SystemAlarmPlayer: AlarmPlayer {

    private enum Tuning {
        static let hapticInterval: TimeInterval = 1.2
    }

    private var isLooping = false
    private var currentSound: AlarmSound = .default
    private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    func start(sound: AlarmSound) {
        currentSound = sound
        guard !isLooping else { return }
        isLooping = true
        configureAudioSessionForAlarm()
        notificationGenerator.notificationOccurred(.warning)
        scheduleNextLoop()
    }

    func stop() {
        guard isLooping else { return }
        isLooping = false
        deactivateAudioSession()
    }

    // MARK: - Private

    private func configureAudioSessionForAlarm() {
        // `.playback` makes the alarm audible even when the ringer
        // switch is muted. `.duckOthers` lowers any music/podcast
        // audio while the alarm plays instead of fighting it.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback,
                                 mode: .default,
                                 options: [.duckOthers])
        try? session.setActive(true, options: [])
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func scheduleNextLoop() {
        guard isLooping else { return }

        AudioServicesPlayAlertSoundWithCompletion(currentSound.systemSoundID) { [weak self] in
            Task { @MainActor in
                guard let self, self.isLooping else { return }
                self.impactGenerator.impactOccurred()
                try? await Task.sleep(for: .seconds(Tuning.hapticInterval))
                self.scheduleNextLoop()
            }
        }
    }
}
