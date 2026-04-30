import SwiftUI

struct SettingsView: View {
    @Environment(WhistleSession.self) private var session
    @Environment(AlarmSoundStore.self) private var alarmSoundStore

    private enum Layout {
        static let targetRange: ClosedRange<Int> = 1...20
        static let sensitivityRange: ClosedRange<Double> = 0...1
    }

    var body: some View {
        @Bindable var session = session
        @Bindable var alarmSoundStore = alarmSoundStore

        VStack(spacing: 14) {
            HStack {
                Text("Sensitivity")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Slider(value: $session.sensitivity, in: Layout.sensitivityRange)
                Text(sensitivityLabel(for: session.sensitivity))
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 60, alignment: .trailing)
            }

            NavigationLink {
                AlarmSoundPickerView(
                    selection: alarmSoundOptionalBinding(
                        for: $alarmSoundStore.defaultSound
                    ),
                    includeDefaultOption: false,
                    defaultSound: alarmSoundStore.defaultSound
                )
            } label: {
                HStack {
                    Text("Alarm")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(alarmSoundStore.defaultSound.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func alarmSoundOptionalBinding(
        for source: Binding<AlarmSound>
    ) -> Binding<AlarmSound?> {
        Binding(
            get: { source.wrappedValue },
            set: { newValue in
                if let newValue {
                    source.wrappedValue = newValue
                }
            }
        )
    }

    private func sensitivityLabel(for value: Double) -> String {
        switch value {
        case ..<0.25: "Very high"
        case ..<0.5:  "High"
        case ..<0.75: "Medium"
        default:      "Low"
        }
    }
}
