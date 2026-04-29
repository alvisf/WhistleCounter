import SwiftUI

struct SettingsView: View {
    @Environment(WhistleSession.self) private var session

    var body: some View {
        @Bindable var session = session

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Target")
                    .font(.subheadline)
                Spacer()
                Stepper(
                    "\(session.targetCount)",
                    value: $session.targetCount,
                    in: 1...20
                )
                .fixedSize()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sensitivity")
                        .font(.subheadline)
                    Spacer()
                    Text(sensitivityLabel(session.sensitivity))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $session.sensitivity, in: 0...1)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func sensitivityLabel(_ value: Double) -> String {
        switch value {
        case ..<0.25: "Very high"
        case ..<0.5:  "High"
        case ..<0.75: "Medium"
        default:      "Low"
        }
    }
}

#Preview {
    SettingsView()
        .environment(WhistleSession())
        .padding()
}
