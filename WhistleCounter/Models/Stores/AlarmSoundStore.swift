import Foundation
import Observation

/// Observable store for the user's default alarm sound. Persists to
/// `UserDefaults`. A recipe with no explicit `alarmSound` falls back
/// to this value.
@Observable
@MainActor
final class AlarmSoundStore {

    private enum Keys {
        static let defaultSound = "alarm.defaultSound"
    }

    // MARK: - Public state

    var defaultSound: AlarmSound {
        didSet { persist() }
    }

    // MARK: - Collaborators

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultSound = Self.load(from: defaults) ?? .default
    }

    // MARK: - Persistence

    private static func load(from defaults: UserDefaults) -> AlarmSound? {
        guard let raw = defaults.string(forKey: Keys.defaultSound) else {
            return nil
        }
        return AlarmSound(rawValue: raw)
    }

    private func persist() {
        defaults.set(defaultSound.rawValue, forKey: Keys.defaultSound)
    }
}
