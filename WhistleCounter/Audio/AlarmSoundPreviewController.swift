import AudioToolbox
import Foundation
import Observation

/// Drives the "preview" audio in `AlarmSoundPickerView`. Plays the
/// selected sound in a loop for up to `previewDurationSec`, then
/// stops. Selecting a different sound resets the timer.
@Observable
@MainActor
final class AlarmSoundPreviewController {

    private enum Tuning {
        static let previewDurationSec: Double = 2.0
    }

    private(set) var previewingSound: AlarmSound?
    private var currentPreviewID = UUID()

    func startPreview(_ sound: AlarmSound) {
        let previewID = UUID()
        currentPreviewID = previewID
        previewingSound = sound
        playLoop(sound: sound, previewID: previewID,
                 deadline: Date().addingTimeInterval(Tuning.previewDurationSec))
    }

    func stop() {
        currentPreviewID = UUID()
        previewingSound = nil
    }

    private func playLoop(sound: AlarmSound, previewID: UUID, deadline: Date) {
        guard previewID == currentPreviewID, Date() < deadline else {
            if previewID == currentPreviewID {
                previewingSound = nil
            }
            return
        }
        AudioServicesPlayAlertSoundWithCompletion(sound.systemSoundID) { [weak self] in
            Task { @MainActor in
                self?.playLoop(sound: sound, previewID: previewID, deadline: deadline)
            }
        }
    }
}
