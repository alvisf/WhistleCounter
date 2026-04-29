import SwiftUI

struct SettingsView: View {
    @Environment(WhistleSession.self) private var session

    private enum Layout {
        static let cardCornerRadius: CGFloat = 12
        static let rowSpacing: CGFloat = 14
        static let targetRange: ClosedRange<Int> = 1...20
        static let sensitivityRange: ClosedRange<Double> = 0...1
    }

    var body: some View {
        @Bindable var session = session

        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            HStack {
                Text("Target")
                    .font(.subheadline)
                Spacer()
                Stepper(
                    "\(session.targetCount)",
                    value: $session.targetCount,
                    in: Layout.targetRange
                )
                .fixedSize()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sensitivity")
                        .font(.subheadline)
                    Spacer()
                    Text(sensitivityLabel(for: session.sensitivity))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $session.sensitivity, in: Layout.sensitivityRange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .fill(Color(.secondarySystemBackground))
        )
    }

    /// Maps a sensitivity value in [0, 1] to a human-readable label.
    /// The slider is reversed in meaning (`0` = most sensitive), which
    /// is why low values show "Very high".
    private func sensitivityLabel(for value: Double) -> String {
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
