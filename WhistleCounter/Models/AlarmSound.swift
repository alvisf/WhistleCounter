import AudioToolbox
import Foundation

/// A selectable alarm sound. Each case maps to an iOS system sound
/// ID that ships with every device — no bundled audio files required.
enum AlarmSound: String, CaseIterable, Codable, Identifiable, Hashable {
    case triTone
    case bell
    case chime
    case glass
    case alert

    var id: String { rawValue }

    /// The numeric iOS system sound identifier.
    var systemSoundID: SystemSoundID {
        switch self {
        case .triTone: 1005
        case .bell:    1013
        case .chime:   1010
        case .glass:   1009
        case .alert:   1007
        }
    }

    var displayName: String {
        switch self {
        case .triTone: "Tri-tone"
        case .bell:    "Bell"
        case .chime:   "Chime"
        case .glass:   "Glass"
        case .alert:   "Alert"
        }
    }

    static let `default`: AlarmSound = .triTone
}
