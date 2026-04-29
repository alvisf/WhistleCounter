import SwiftUI

/// Reusable picker for selecting an `AlarmSound`.
///
/// Supports an optional "Default" row that sets the binding to nil,
/// used when the picker represents an **override** (e.g. a per-recipe
/// alarm sound) that can fall back to the global default.
struct AlarmSoundPickerView: View {

    @Binding var selection: AlarmSound?
    let includeDefaultOption: Bool
    let defaultSound: AlarmSound

    @State private var preview = AlarmSoundPreviewController()

    var body: some View {
        List {
            if includeDefaultOption {
                Section {
                    defaultRow
                }
            }
            Section {
                ForEach(AlarmSound.allCases) { sound in
                    soundRow(sound)
                }
            }
        }
        .navigationTitle("Alarm sound")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
    }

    // MARK: - Rows

    private var defaultRow: some View {
        Button {
            selection = nil
            preview.startPreview(defaultSound)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Default")
                        .foregroundStyle(.primary)
                    Text(defaultSound.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selection == nil {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private func soundRow(_ sound: AlarmSound) -> some View {
        Button {
            selection = sound
            preview.startPreview(sound)
        } label: {
            HStack {
                Text(sound.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if preview.previewingSound == sound {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.tint)
                        .symbolEffect(.pulse, options: .repeating)
                } else if selection == sound {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }
}

#Preview("With default option") {
    NavigationStack {
        AlarmSoundPickerView(
            selection: .constant(nil),
            includeDefaultOption: true,
            defaultSound: .triTone
        )
    }
}

#Preview("Without default option") {
    NavigationStack {
        AlarmSoundPickerView(
            selection: .constant(.bell),
            includeDefaultOption: false,
            defaultSound: .triTone
        )
    }
}
