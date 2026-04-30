import SwiftUI

/// Clock-app-style stopwatch controls: two large circular buttons
/// with Reset (gray, left) and Start/Stop (green/red, right).
struct ControlsView: View {
    @Environment(WhistleSession.self) private var session

    private enum Layout {
        static let circleSize: CGFloat = 96
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                resetButton
                Spacer()
                listenToggleButton
            }
            if let error = session.errorMessage {
                errorLabel(error)
            }
        }
    }

    private var resetButton: some View {
        Button(action: session.reset) {
            Text("Reset")
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .frame(width: Layout.circleSize, height: Layout.circleSize)
                .background(Color(.systemGray), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var listenToggleButton: some View {
        Button(action: toggleListening) {
            Text(session.isListening ? "Stop" : "Start")
                .font(.body.weight(.medium))
                .foregroundStyle(session.isListening ? .red : .green)
                .frame(width: Layout.circleSize, height: Layout.circleSize)
                .background(
                    session.isListening
                        ? Color.red.opacity(0.3)
                        : Color.green.opacity(0.3),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
    }

    private func errorLabel(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
    }

    private func toggleListening() {
        if session.isListening {
            session.stop()
        } else {
            session.start()
        }
    }
}

#Preview {
    ControlsView()
        .environment(WhistleSession())
        .padding()
}
