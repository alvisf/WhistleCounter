import SwiftUI

struct SettingsView: View {
    @Environment(WhistleSession.self) private var session
    @Environment(AlarmSoundStore.self) private var alarmSoundStore

    private enum Layout {
        static let sensitivityRange: ClosedRange<Double> = 0...1
    }

    var body: some View {
        @Bindable var session = session
        @Bindable var alarmSoundStore = alarmSoundStore

        VStack(spacing: 0) {
            // Sensitivity row
            HStack {
                Text("Sensitivity")
                    .font(.subheadline)
                    .fixedSize()
                Slider(value: $session.sensitivity, in: Layout.sensitivityRange)
                Text(sensitivityLabel(for: session.sensitivity))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 65, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
                .padding(.leading, 16)

            // Alarm row
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
                    Spacer()
                    Text(alarmSoundStore.defaultSound.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
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
